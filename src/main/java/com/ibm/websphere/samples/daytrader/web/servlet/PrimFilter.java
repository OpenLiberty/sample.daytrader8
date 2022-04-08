/**
 * (C) Copyright IBM Corporation 2015, 2022.
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
package com.ibm.websphere.samples.daytrader.web.servlet;

import java.io.IOException;

import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.annotation.WebFilter;

import com.ibm.websphere.samples.daytrader.interfaces.Trace;
import com.ibm.websphere.samples.daytrader.util.Log;

@WebFilter(filterName = "PrimFilter", urlPatterns = "/drive/*")
@Trace
public class PrimFilter implements Filter {
	
  private static final int DRIVE_MEMORY = Integer.getInteger("DRIVE_MEMORY", 0);
  private static final int DRIVE_LATENCY = Integer.getInteger("DRIVE_LATENCY", 0);
  
  static {
    if (DRIVE_MEMORY > 0) {
      Log.warning("DRIVE_MEMORY=" + DRIVE_MEMORY + " has been specified which will allocate that many bytes on every /app* request");
    }
    if (DRIVE_LATENCY > 0) {
      Log.warning("DRIVE_LATENCY=" + DRIVE_LATENCY + " has been specified which will sleep that many milliseconds on every /app* request");
    }
  }

  /**
   * @see Filter#init(FilterConfig)
   */
  private FilterConfig filterConfig = null;

  @Override
  public void init(FilterConfig filterConfig) throws ServletException {
    this.filterConfig = filterConfig;
  }

  /**
   * @see Filter#doFilter(ServletRequest, ServletResponse, FilterChain)
   */
  @Override
  public void doFilter(ServletRequest req, ServletResponse resp, FilterChain chain) throws IOException, ServletException {

    if (filterConfig == null) {
      return;
    }

    if (DRIVE_MEMORY > 0) {
      byte[] memory = new byte[DRIVE_MEMORY];
      // Not sure if Java will optimize this away if we don't use it, so just
      // do something trivial
      int count = 0;
      for (byte b : memory) {
        if ((b & 0x01) > 0) {
          count++;
        }
      }
      if (count > 0) {
        Log.error("Something that shouldn't happen");
      }
	}

    if (DRIVE_LATENCY > 0) {
      try {
        Thread.sleep(DRIVE_LATENCY);
      } catch (InterruptedException e) {
        e.printStackTrace();
      }
    }

    chain.doFilter(req, resp/* wrapper */);
  }

  /**
   * @see Filter#destroy()
   */
  @Override
  public void destroy() {
    this.filterConfig = null;
  }

}
