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

package io.ballerina.stdlib.smb.iterator;

import io.ballerina.lib.data.csvdata.csv.Native;
import io.ballerina.lib.data.csvdata.utils.ModuleUtils;
import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.creators.TypeCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.PredefinedTypes;
import io.ballerina.runtime.api.types.StreamType;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.types.TypeTags;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.utils.TypeUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;
import io.ballerina.stdlib.smb.util.SmbUtil;

import java.io.IOException;
import java.io.InputStream;

import static io.ballerina.stdlib.smb.iterator.ByteIterator.NATIVE_INPUT_STREAM;
import static io.ballerina.stdlib.smb.iterator.ByteIterator.NATIVE_LAX_DATA_BINDING;
import static io.ballerina.stdlib.smb.iterator.ByteIterator.NATIVE_STREAM_VALUE_TYPE;
import static io.ballerina.stdlib.smb.client.SmbClient.SMB_ERROR;

/**
 * Iterator utilities for streaming CSV content in SMB files.
 */
public class CsvIterator {
    private static final String KEY_INDEX = "index";
    private static final String KEY_DATA = "data";
    private static final String KEY_LENGTH = "length";
    private static final String REC_STRING_ARRAY_ENTRY = "ContentCsvStringArrayStreamEntry";
    private static final String REC_RECORD_ENTRY = "ContentCsvRecordStreamEntry";
    private static final BString IS_CLOSED = StringUtils.fromString("isClosed");
    private static final BString FIELD_VALUE = StringUtils.fromString("value");

    private CsvIterator() {
    }

    /**
     * Creates a string array stream from CSV content.
     *
     * @param content         The input stream containing CSV data
     * @param streamValueType The expected element type
     * @param laxDataBinding  Whether to use lax data binding
     * @return A Ballerina stream value
     */
    public static Object createStringArrayStream(InputStream content, Type streamValueType, boolean laxDataBinding) {
        BObject contentCsvStreamObject = ValueCreator.createObjectValue(
                io.ballerina.stdlib.smb.util.ModuleUtils.getModule(), "ContentCsvStringArrayStream", null, null
        );
        contentCsvStreamObject.addNativeData(NATIVE_INPUT_STREAM, content);
        contentCsvStreamObject.addNativeData(NATIVE_LAX_DATA_BINDING, laxDataBinding);
        contentCsvStreamObject.addNativeData(NATIVE_STREAM_VALUE_TYPE, streamValueType);
        StreamType streamType = TypeCreator.createStreamType(streamValueType,
                TypeCreator.createUnionType(PredefinedTypes.TYPE_ERROR, PredefinedTypes.TYPE_NULL));
        return ValueCreator.createStreamValue(streamType, contentCsvStreamObject);
    }

    /**
     * Creates a record stream from CSV content.
     *
     * @param content         The input stream containing CSV data
     * @param streamValueType The expected element type
     * @param laxDataBinding  Whether to use lax data binding
     * @return A Ballerina stream value
     */
    public static Object createRecordStream(InputStream content, Type streamValueType, boolean laxDataBinding) {
        BObject contentCsvStreamObject = ValueCreator.createObjectValue(
                io.ballerina.stdlib.smb.util.ModuleUtils.getModule(), "ContentCsvRecordStream", null, null
        );
        contentCsvStreamObject.addNativeData(NATIVE_INPUT_STREAM, content);
        contentCsvStreamObject.addNativeData(NATIVE_LAX_DATA_BINDING, laxDataBinding);
        contentCsvStreamObject.addNativeData(NATIVE_STREAM_VALUE_TYPE, streamValueType);
        StreamType streamType = TypeCreator.createStreamType(streamValueType,
                TypeCreator.createUnionType(PredefinedTypes.TYPE_ERROR, PredefinedTypes.TYPE_NULL));
        return ValueCreator.createStreamValue(streamType, contentCsvStreamObject);
    }

    /**
     * Gets the next CSV row from the stream.
     * This method is called by Ballerina runtime when iterating the stream.
     *
     * @param environment    The Ballerina runtime environment
     * @param recordIterator The iterator object
     * @return The next record with CSV row value, or null if stream is exhausted
     */
    public static Object next(Environment environment, BObject recordIterator) {
        final Type elementType = (Type) recordIterator.getNativeData(NATIVE_STREAM_VALUE_TYPE);
        final String recordTypeName = resolveRecordTypeName(elementType);
        final BMap<BString, Object> streamEntry =
                ValueCreator.createRecordValue(io.ballerina.stdlib.smb.util.ModuleUtils.getModule(), recordTypeName);

        Object dataIndex = recordIterator.getNativeData(KEY_INDEX);
        if (dataIndex == null) {
            final InputStream inputStream = (InputStream) recordIterator.getNativeData(NATIVE_INPUT_STREAM);
            if (inputStream == null) {
                recordIterator.set(IS_CLOSED, true);
                return SmbUtil.createError("Input stream is not available", SMB_ERROR);
            }
            try {
                byte[] bytes = inputStream.readAllBytes();
                inputStream.close();
                boolean laxDataBinding = (boolean) recordIterator.getNativeData(NATIVE_LAX_DATA_BINDING);

                BMap<BString, Object> parseOptions =
                        ValueCreator.createRecordValue(ModuleUtils.getModule(), "ParseOptions");
                parseOptions.put(StringUtils.fromString("allowDataProjection"), laxDataBinding);
                Object parsed = Native.parseBytes(environment, ValueCreator.createArrayValue(bytes),
                        parseOptions, ValueCreator.createTypedescValue(TypeCreator.createArrayType(elementType)));

                if (TypeUtils.getType(parsed).getTag() == TypeTags.ERROR_TAG) {
                    recordIterator.set(IS_CLOSED, true);
                    return SmbUtil.createError(((BError) parsed).getErrorMessage().getValue(), SMB_ERROR);
                }

                if (!(TypeUtils.getType(parsed).getTag() == TypeTags.ARRAY_TAG)) {
                    recordIterator.set(IS_CLOSED, true);
                    return SmbUtil.createError("Unexpected parse result type", SMB_ERROR);
                }

                BArray dataArray = (BArray) parsed;
                long length = dataArray.getLength();
                if (length == 0) {
                    recordIterator.set(IS_CLOSED, true);
                    return null;
                }
                recordIterator.addNativeData(KEY_DATA, dataArray);
                recordIterator.addNativeData(KEY_INDEX, 1);
                recordIterator.addNativeData(KEY_LENGTH, length);

                streamEntry.put(FIELD_VALUE, dataArray.get(0));
                return streamEntry;
            } catch (IOException exception) {
                recordIterator.set(IS_CLOSED, true);
                return SmbUtil.createError("Unable to read input stream: " + exception.getMessage(), SMB_ERROR);
            } catch (Throwable throwable) {
                recordIterator.set(IS_CLOSED, true);
                return SmbUtil.createError("CSV parsing failed: " + throwable.getMessage(), SMB_ERROR);
            }
        }
        int index = (int) dataIndex;
        long count = (Long) recordIterator.getNativeData(KEY_LENGTH);
        if (index >= count) {
            recordIterator.set(IS_CLOSED, true);
            return null;
        }

        BArray dataArray = (BArray) recordIterator.getNativeData(KEY_DATA);
        if (dataArray == null) {
            recordIterator.set(IS_CLOSED, true);
            return SmbUtil.createError("Iterator state corrupted: data is missing", SMB_ERROR);
        }

        recordIterator.addNativeData(KEY_INDEX, index + 1);
        streamEntry.put(FIELD_VALUE, dataArray.get(index));
        return streamEntry;
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
        } catch (IOException e) {
            return SmbUtil.createError("Unable to close input stream: " + e.getMessage(), SMB_ERROR);
        } finally {
            recordIterator.set(IS_CLOSED, true);
        }
        return null;
    }

    private static String resolveRecordTypeName(Type type) {
        return (type != null && type.getTag() == TypeTags.ARRAY_TAG)
                ? REC_STRING_ARRAY_ENTRY : REC_RECORD_ENTRY;
    }
}
