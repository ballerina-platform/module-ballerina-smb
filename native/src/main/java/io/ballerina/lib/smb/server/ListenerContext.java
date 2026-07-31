/*
 * Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.lib.smb.server;

import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;

/**
 * Encapsulates the listener wide state a dispatch reads. The caller is a function of the listener
 * configuration alone — it has nothing to do with the path a given service monitors — so it belongs here
 * rather than on each {@link ServiceContext}.
 *
 * @param config The listener configuration
 * @param caller The listener's {@code smb:Caller}, or {@code null} when no attached service declares one
 */
public record ListenerContext(BMap<BString, Object> config, BObject caller) {
}
