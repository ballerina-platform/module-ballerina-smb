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

module io.ballerina.lib.smb {
    requires io.ballerina.runtime;
    requires io.ballerina.lang;
    requires io.ballerina.stdlib.io;
    requires io.ballerina.tools.api;
    requires org.slf4j;
    requires java.logging;
    requires java.security.jgss;
    requires io.ballerina.lib.data;
    requires io.ballerina.lib.data.xmldata;
    requires io.ballerina.lib.data.csvdata;
    requires com.hierynomus.smbj;
    exports io.ballerina.lib.smb.client;
    exports io.ballerina.lib.smb.server;
    exports io.ballerina.lib.smb.util;
    exports io.ballerina.lib.smb.iterator;
}
