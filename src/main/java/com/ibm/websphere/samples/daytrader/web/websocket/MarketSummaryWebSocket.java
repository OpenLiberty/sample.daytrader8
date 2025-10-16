/**
 * (C) Copyright IBM Corporation 2015, 2025.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.ibm.websphere.samples.daytrader.web.websocket;

import java.io.IOException;
import java.util.Iterator;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;

import javax.annotation.Priority;
import javax.annotation.Resource;
import javax.enterprise.concurrent.ManagedScheduledExecutorService;
import javax.enterprise.event.ObservesAsync;
import javax.enterprise.inject.Any;
import javax.enterprise.inject.Instance;
import javax.interceptor.Interceptor;
import javax.inject.Inject;
import javax.json.JsonObject;
import javax.websocket.CloseReason;
import javax.websocket.EndpointConfig;
import javax.websocket.OnClose;
import javax.websocket.OnError;
import javax.websocket.OnMessage;
import javax.websocket.OnOpen;
import javax.websocket.Session;
import javax.websocket.server.ServerEndpoint;



import com.ibm.websphere.samples.daytrader.entities.QuoteDataBean;
import com.ibm.websphere.samples.daytrader.interfaces.MarketSummaryUpdate;
import com.ibm.websphere.samples.daytrader.interfaces.QuotePriceChange;
import com.ibm.websphere.samples.daytrader.interfaces.TradeServices;
import com.ibm.websphere.samples.daytrader.util.Log;
import com.ibm.websphere.samples.daytrader.util.RecentQuotePriceChangeList;
import com.ibm.websphere.samples.daytrader.util.TradeConfig;
import com.ibm.websphere.samples.daytrader.util.TradeRunTimeModeLiteral;


/** This class is a WebSocket EndPoint that sends the Market Summary in JSON form and
*  encodes recent quote price changes when requested or when triggered by CDI events.
**/

@ServerEndpoint(value = "/marketsummary",encoders={QuotePriceChangeListEncoder.class},decoders={ActionDecoder.class})
public class MarketSummaryWebSocket {

  @Inject
  RecentQuotePriceChangeList recentQuotePriceChangeList;

  @Resource
  private ManagedScheduledExecutorService managedScheduledExecutorService;

  private TradeServices tradeAction;

  private static final List<Session> SESSIONS = new CopyOnWriteArrayList<>();
  private static final int SCHEDULER_PERIOD = Integer.parseInt(System.getProperty("dt.ws.period", "2"));

  private final CountDownLatch latch = new CountDownLatch(1);

  private static boolean sendRecentQuotePriceChangeList = false;
  private static ScheduledFuture<?> scheduler = null;

  @Inject
  public MarketSummaryWebSocket(@Any Instance<TradeServices> services) {
    tradeAction = services.select(new TradeRunTimeModeLiteral(TradeConfig.getRunTimeModeNames()[TradeConfig.getRunTimeMode()])).get();
  }

  // should never be used
  public MarketSummaryWebSocket(){
  }

  @OnOpen
  public void onOpen(final Session session, EndpointConfig ec) {
    Log.trace("MarketSummaryWebSocket:onOpen -- session -->" + session + "<--");

    // Start scheduled service on first onOpen to send quotePriceChanges every 2 seconds (if there is an update)
    synchronized(SESSIONS) {
      if (SESSIONS.size() == 0) {
        Log.trace("MarketSummaryWebSocket:onOpen -- start scheduler");
        startScheduler();
      }

      SESSIONS.add(session);
    }

    Log.trace("MarketSummaryWebSocket:onOpen -- sessions.size -->" + SESSIONS.size() + "<--");
    latch.countDown();
  }

	@OnMessage
  public void sendMarketSummary(ActionMessage message, Session currentSession) {

    String action = message.getDecodedAction();

    Log.trace("MarketSummaryWebSocket:sendMarketSummary -- received -->" + action + "<--");
    try {
      // Make sure onopen is finished
      latch.await();
    } catch (Exception e) {
      e.printStackTrace();
      return;
    }

    if (action != null && action.equals("updateMarketSummary")) {

      JsonObject mkSummary = null;

      try {
        mkSummary = tradeAction.getMarketSummary().toJSON();
      } catch (Exception e) {
        e.printStackTrace();
        return;
      }

      synchronized (currentSession) {
        if (currentSession.isOpen()) {
          Log.trace("MarketSummaryWebSocket:sendMarketSummary -- start writing market summary -->" + currentSession + "<--");
          try {
            currentSession.getBasicRemote().sendText(mkSummary.toString());
          } catch (IOException e) {
            e.printStackTrace();
            return;
          }
          Log.trace("MarketSummaryWebSocket:sendMarketSummary -- done writing market summary  -->" + currentSession + "<--");
        }
      }
    } else if (action != null && action.equals("updateRecentQuotePriceChange")) {
      if (!recentQuotePriceChangeList.isEmpty()) {
        synchronized (currentSession) {
          if (currentSession.isOpen()) {
            Log.trace("MarketSummaryWebSocket:sendMarketSummary -- start writing quote changes -->" + currentSession + "<--");
            try {
              currentSession.getBasicRemote().sendObject(recentQuotePriceChangeList.recentList());
            } catch (Exception e) {
              e.printStackTrace();
              return;
            }
            Log.trace("MarketSummaryWebSocket:sendMarketSummary -- done writing quote changes -->" + currentSession + "<--");
          }
        }
      }
    }
  }

  @OnError
  public void onError(Throwable t, Session currentSession) {
    Log.trace("MarketSummaryWebSocket:onError -- session -->" + currentSession + "<--");
    t.printStackTrace();
  }

  @OnClose
  public void onClose(Session session, CloseReason reason) {
    Log.trace("MarketSummaryWebSocket:onClose -- session -->" + session.getId() + "<--" + reason.getReasonPhrase());
    synchronized(SESSIONS) {
      SESSIONS.remove(session);
      if (SESSIONS.size() == 0) {  
        Log.trace("MarketSummaryWebSocket:onClose -- cancel scheduler");
        scheduler.cancel(false);
      }
    }
  
    Log.trace("MarketSummaryWebSocket:onClose -- sessions.size -->" + SESSIONS.size() + "<--");
  }

  public void onMarketSummarytUpdate(@ObservesAsync @Priority(Interceptor.Priority.APPLICATION) @MarketSummaryUpdate String event) {

    JsonObject mkSummary = null;
    try {
      mkSummary = tradeAction.getMarketSummary().toJSON();
    } catch (Exception e) {
      e.printStackTrace();
      return;
    }

    Iterator<Session> failSafeIterator = SESSIONS.iterator();
    while (failSafeIterator.hasNext()) {
      Session session = failSafeIterator.next();
      synchronized (session) {
        if (session.isOpen()) {
          Log.trace("MarketSummaryWebSocket:onMarketSummaryUpdate -- start writing -->" + session + "<--");
          try {
            session.getBasicRemote().sendText(mkSummary.toString());
            Log.trace("MarketSummaryWebSocket:onMarketSummaryUpdate -- done writing -->" + session + "<--");
          } catch (IOException e) {
            e.printStackTrace();
          }
        }
      }
    }
  }
 
  private void sendRecentQuotePriceChangeList() {
    List<QuoteDataBean> list = recentQuotePriceChangeList.recentList();
    Iterator<Session> failSafeIterator = SESSIONS.iterator();
    while (failSafeIterator.hasNext()) {
      Session session = failSafeIterator.next();
      synchronized (session) {
        if (session.isOpen()) {
          Log.trace("MarketSummaryWebSocket:sendRecentQuotePriceChangeList -- start writing -->" + session + "<--");
          try {
            session.getBasicRemote().sendObject(list);
            Log.trace("MarketSummaryWebSocket:sendRecentQuotePriceChangeList -- done writing -->" + session + "<--");
          } catch (Exception e) {
            e.printStackTrace();
          }
        }
      }
    }
  }

  private void startScheduler() {
		scheduler = managedScheduledExecutorService.scheduleAtFixedRate(() -> {
        Log.trace("MarketSummaryWebSocket: Executing static scheduled task at: " + System.currentTimeMillis());
        if (sendRecentQuotePriceChangeList) {
          Log.trace("MarketSummaryWebSocket: sendList = true");
          sendRecentQuotePriceChangeList();
          sendRecentQuotePriceChangeList = false;
        } else {
          Log.trace("MarketSummaryWebSocket: sendList = false");
        }
      }, 1, SCHEDULER_PERIOD, TimeUnit.SECONDS);
	}

  public static void quotePriceChangeNotification(@ObservesAsync @Priority(Interceptor.Priority.APPLICATION) @QuotePriceChange String event) {
    Log.trace("MarketSummaryWebSocket:quotePriceChangeNotification -- notification received");
    sendRecentQuotePriceChangeList = true;
  }
}
