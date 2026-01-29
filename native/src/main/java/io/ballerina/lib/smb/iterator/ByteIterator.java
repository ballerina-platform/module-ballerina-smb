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

import io.ballerina.lib.smb.util.ModuleUtils;
import io.ballerina.lib.smb.util.SmbUtil;
import io.ballerina.runtime.api.creators.TypeCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.PredefinedTypes;
import io.ballerina.runtime.api.types.StreamType;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Arrays;

import static io.ballerina.lib.smb.client.SmbClient.SMB_ERROR;

/**
 * Utility class for iterating over byte stream content from SMB files.
 */
public class ByteIterator {
    public static final String NATIVE_INPUT_STREAM = "nativeInputStream";
    public static final String NATIVE_LAX_DATA_BINDING = "nativeLaxDataBinding";
    public static final String NATIVE_STREAM_VALUE_TYPE = "nativeStreamValueType";
    public static final int ARRAY_SIZE = 65536;
    public static final BString FIELD_VALUE = StringUtils.fromString("value");
    public static final BString IS_CLOSED = StringUtils.fromString("isClosed");

    private ByteIterator() {
    }

    public static Object createByteStream(byte[] content) {
        InputStream inputStream = new ByteArrayInputStream(content);
        return createByteStream(inputStream);
    }

    public static Object createByteStream(InputStream inputStream) {
        BObject contentByteStreamObject = ValueCreator.createObjectValue(
                ModuleUtils.getModule(), "ContentByteStream", null, null
        );
        contentByteStreamObject.addNativeData(NATIVE_INPUT_STREAM, inputStream);
        StreamType streamType = TypeCreator.createStreamType(TypeCreator.createArrayType(PredefinedTypes.TYPE_BYTE),
                TypeCreator.createUnionType(PredefinedTypes.TYPE_ERROR, PredefinedTypes.TYPE_NULL)
        );
        return ValueCreator.createStreamValue(streamType, contentByteStreamObject);
    }

    public static Object next(BObject recordIterator) {
        InputStream inputStream = (InputStream) recordIterator.getNativeData(NATIVE_INPUT_STREAM);
        if (inputStream == null) {
            recordIterator.set(IS_CLOSED, true);
            return null;
        }

        BMap<BString, Object> streamEntry = ValueCreator
                .createRecordValue(ModuleUtils.getModule(), "ContentStreamEntry");
        try {
            byte[] buffer = new byte[ARRAY_SIZE];
            int readNumber = inputStream.read(buffer);
            if (readNumber == -1) {
                inputStream.close();
                recordIterator.set(IS_CLOSED, true);
                return null;
            }
            byte[] returnArray = (readNumber < ARRAY_SIZE) ? Arrays.copyOfRange(buffer, 0, readNumber) : buffer;
            streamEntry.put(FIELD_VALUE, ValueCreator.createArrayValue(returnArray));
            return streamEntry;
        } catch (IOException e) {
            return SmbUtil.createError("Unable to read byte stream: " + e.getMessage(), SMB_ERROR);
        }
    }

    /**
     * Closes the stream iterator.
     *
     * @param recordIterator The iterator object
     * @return null (no error) or an error
     */
    public static Object close(BObject recordIterator) {
        try {
            Object inputStream = recordIterator.getNativeData(NATIVE_INPUT_STREAM);
            if (inputStream != null) {
                ((InputStream) inputStream).close();
            }
            recordIterator.set(IS_CLOSED, true);
        } catch (IOException e) {
            return SmbUtil.createError("Unable to close byte stream: " + e.getMessage(), SMB_ERROR);
        }
        return null;
    }
}
