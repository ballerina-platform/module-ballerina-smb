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

import java.util.regex.Pattern;

/**
 * A {@code fileNamePattern} compiled once, when the service is attached or the listener is initialized.
 *
 * @param pattern The compiled regex
 */
public record FileNamePattern(Pattern pattern) {

    /**
     * Compiles the given regex. A regex that does not compile is reported to whoever configured it, rather
     * than degrading into a pattern that silently matches nothing.
     *
     * @param regex The regex to compile
     * @return The compiled pattern
     * @throws java.util.regex.PatternSyntaxException if the regex is not a valid pattern
     */
    public static FileNamePattern compile(String regex) {
        return new FileNamePattern(Pattern.compile(regex));
    }

    /**
     * Matches the given file name against this pattern.
     *
     * @param fileName The file name to match
     * @return true if the whole file name matches
     */
    public boolean matches(String fileName) {
        return pattern.matcher(fileName).matches();
    }
}
