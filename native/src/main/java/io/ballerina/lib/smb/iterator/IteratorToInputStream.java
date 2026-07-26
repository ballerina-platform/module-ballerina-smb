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

package io.ballerina.lib.smb.iterator;

import io.ballerina.lib.smb.util.CSVUtils;
import io.ballerina.lib.smb.util.SmbUtil;
import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.types.TypeTags;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Iterator;
import java.util.NoSuchElementException;

import static io.ballerina.lib.smb.client.SmbClient.SMB_ERROR;

/**
 * Converts a Ballerina stream iterator into a Java {@link Iterator} of {@link InputStream}s.
 * Each element produced by the Ballerina iterator is converted to bytes and wrapped in a
 * {@link ByteArrayInputStream}.
 */
public final class IteratorToInputStream implements Iterator<InputStream> {

    private static final BString FIELD_VALUE = StringUtils.fromString("value");
    private final Environment env;
    private final BObject iterator;
    private InputStream nextStream;
    private boolean hasChecked;
    private boolean isFirstRow;

    public IteratorToInputStream(Environment env, BObject iterator) {
        this(env, iterator, true);
    }

    public IteratorToInputStream(Environment env, BObject iterator, boolean addHeader) {
        this.env = env;
        this.iterator = iterator;
        this.isFirstRow = addHeader;
    }

    @Override
    public boolean hasNext() {
        if (hasChecked) {
            return nextStream != null;
        }
        nextStream = fetchNextStream();
        hasChecked = true;
        return nextStream != null;
    }

    @Override
    public InputStream next() {
        if (!hasChecked && !hasNext()) {
            throw new NoSuchElementException();
        }
        hasChecked = false;
        InputStream result = nextStream;
        nextStream = null;
        return result;
    }

    @SuppressWarnings("unchecked")
    private InputStream fetchNextStream() {
        final Object next;
        try {
            next = env.getRuntime().callMethod(iterator, "next", null);
        } catch (Exception e) {
            throw SmbUtil.createError("Failed to read iterator: " + e.getMessage(), SMB_ERROR);
        }
        if (next == null) {
            return null;
        }
        if (next instanceof io.ballerina.runtime.api.values.BError err) {
            throw SmbUtil.createError("Iterator error: " + err.getMessage(), SMB_ERROR);
        }

        byte[] bytes = toBytes(next);
        if (bytes.length == 0) {
            return null;
        }
        isFirstRow = false;
        return new ByteArrayInputStream(bytes);
    }

    @SuppressWarnings("unchecked")
    private byte[] toBytes(Object value) {
        BMap<BString, Object> streamRecord = (BMap<BString, Object>) value;
        Object val = streamRecord.get(FIELD_VALUE);

        if (val instanceof BArray array) {
            return bytesFromArray(array);
        }
        BMap<BString, Object> recordValue = (BMap<BString, Object>) val;
        return bytesFromRecord(recordValue, isFirstRow);
    }

    private static byte[] bytesFromArray(BArray array) {
        if (array.getElementType().getTag() == TypeTags.BYTE_TAG) {
            return array.getBytes();
        }
        String csvRow = CSVUtils.convertArrayToCsvRow(array) + System.lineSeparator();
        return csvRow.getBytes(StandardCharsets.UTF_8);
    }

    private static byte[] bytesFromRecord(BMap<BString, Object> balRecord, boolean includeHeader) {
        String csvRow = CSVUtils.convertRecordToCsvRow(balRecord, includeHeader) + System.lineSeparator();
        return csvRow.getBytes(StandardCharsets.UTF_8);
    }
}
