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

package io.ballerina.stdlib.smb.client;

import com.hierynomus.msdtyp.AccessMask;
import com.hierynomus.msfscc.FileAttributes;
import com.hierynomus.msfscc.fileinformation.FileAllInformation;
import com.hierynomus.msfscc.fileinformation.FileIdBothDirectoryInformation;
import com.hierynomus.mssmb2.SMB2CreateDisposition;
import com.hierynomus.mssmb2.SMB2CreateOptions;
import com.hierynomus.mssmb2.SMB2Dialect;
import com.hierynomus.mssmb2.SMB2ShareAccess;
import com.hierynomus.protocol.commons.EnumWithValue;
import com.hierynomus.smbj.SMBClient;
import com.hierynomus.smbj.SmbConfig;
import com.hierynomus.smbj.auth.AuthenticationContext;
import com.hierynomus.smbj.auth.GSSAuthenticationContext;
import com.hierynomus.smbj.connection.Connection;
import com.hierynomus.smbj.session.Session;
import com.hierynomus.smbj.share.DiskShare;
import com.hierynomus.smbj.share.File;
import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.creators.TypeCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.ArrayType;
import io.ballerina.runtime.api.types.PredefinedTypes;
import io.ballerina.runtime.api.types.TupleType;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.types.TypeTags;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BDecimal;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;
import io.ballerina.runtime.api.values.BTypedesc;
import io.ballerina.stdlib.smb.iterator.ByteIterator;
import io.ballerina.stdlib.smb.iterator.CsvIterator;
import io.ballerina.stdlib.smb.util.CSVUtils;
import io.ballerina.stdlib.smb.util.ModuleUtils;
import io.ballerina.stdlib.smb.util.SmbContentConverter;
import io.ballerina.stdlib.smb.util.SmbUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import javax.security.auth.Subject;
import javax.security.auth.callback.Callback;
import javax.security.auth.callback.CallbackHandler;
import javax.security.auth.callback.NameCallback;
import javax.security.auth.callback.PasswordCallback;
import javax.security.auth.login.AppConfigurationEntry;
import javax.security.auth.login.Configuration;
import javax.security.auth.login.LoginContext;
import javax.security.auth.login.LoginException;

public class SmbClient {
    public static final String SMB_CLIENT_CONNECTOR = "SmbClientConnector";
    public static final String SMB_ORG_NAME = "ballerina";
    public static final String SMB_MODULE_NAME = "smb";
    public static final int ARRAY_SIZE = 65536;
    public static final String SMB_ERROR = "Error";
    public static final String ENDPOINT_CONFIG_HOST = "host";
    public static final String ENDPOINT_CONFIG_SHARE = "share";
    public static final String ENDPOINT_CONFIG_PORT = "port";
    public static final String ENDPOINT_CONFIG_USERNAME = "username";
    public static final String ENDPOINT_CONFIG_PASS_KEY = "password";
    public static final String ENDPOINT_CONFIG_DOMAIN = "domain";
    public static final String ENDPOINT_CONFIG_AUTH = "auth";
    public static final String ENDPOINT_CONFIG_CREDENTIALS = "credentials";
    public static final String ENDPOINT_CONFIG_LAX_DATA_BINDING = "laxDataBinding";
    public static final String ENDPOINT_CONFIG_CSV_FAIL_SAFE = "csvFailSafe";
    public static final String ENDPOINT_CONFIG_DIALECTS = "dialects";
    public static final String ENDPOINT_CONFIG_SIGN_REQUIRED = "signRequired";
    public static final String ENDPOINT_CONFIG_ENCRYPT_DATA = "encryptData";
    public static final String ENDPOINT_CONFIG_ENABLE_DFS = "enableDfs";
    public static final String ENDPOINT_CONFIG_BUFFER_SIZE = "bufferSize";
    public static final String ENDPOINT_CONFIG_CONNECT_TIMEOUT = "connectTimeout";
    public static final String AUTH_TYPE = "authType";
    public static final String AUTH_TYPE_NTLM = "NTLM";
    public static final String AUTH_TYPE_KERBEROS = "KERBEROS";
    public static final String AUTH_TYPE_ANONYMOUS = "ANONYMOUS";
    public static final String KERBEROS_CONFIG = "kerberosConfig";
    public static final String KERBEROS_PRINCIPAL = "principal";
    public static final String KERBEROS_KEYTAB = "keytab";
    public static final String KERBEROS_CONFIG_FILE = "configFile";
    public static final String SMB_CONNECTION = "SmbConnection";
    public static final String SMB_SESSION = "SmbSession";
    public static final String SMB_SHARE = "SmbShare";
    public static final String DIALECT_SMB_3_1_1 = "SMB_3_1_1";
    public static final String DIALECT_SMB_3_0 = "SMB_3_0";
    public static final String DIALECT_SMB_2_1 = "SMB_2_1";
    public static final String DIALECT_SMB_2_0_2 = "SMB_2_0_2";
    public static final String WRITE_OPTION_APPEND = "APPEND";
    private static final Logger log = LoggerFactory.getLogger(SmbClient.class);
    private static final String CLIENT_CLOSED_ERROR_MESSAGE =
            "SMB Client is already closed, hence further operations are not allowed";
    private static final String ON_CLOSE_ERROR = "Error occurred while closing the SMB client: ";
    public static final String MISSING_CREDENTIALS_FOR_AUTH_ERROR =
            "Credentials must be provided for the specified auth configuration";
    public static final String MISSING_CREDENTIALS_FOR_KERBEROS_ERROR =
            "Credentials with password must be provided for Kerberos authentication when keytab is not specified";
    public static final String DIALECT_NOT_SPECIFIED_ERROR = "At least one dialect must be specified";

    private static final Set<String> EXECUTABLE_EXTENSIONS = Set.of(
            "exe", "bat", "cmd", "com", "msi", "ps1", "vbs", "wsf", "jar"
    );
    public static final String FILE_INFO_TYPE = "FileInfo";
    public static final String CLIENT_INITIALIZATION_ERROR = "Failed to initialize SMB client: ";
    public static final String DIRECTORY_CREATE_ERROR = "Failed to create directory: ";
    public static final String FILE_WRITE_ERROR = "Failed to write to file: ";
    public static final BString PATH = StringUtils.fromString("path");
    public static final BString SIZE = StringUtils.fromString("size");
    public static final BString MODIFIED_AT = StringUtils.fromString("modifiedAt");
    public static final BString CREATED_AT = StringUtils.fromString("createdAt");
    public static final BString ACCESSED_AT = StringUtils.fromString("accessedAt");
    public static final BString WRITTEN_AT = StringUtils.fromString("writtenAt");
    public static final BString NAME = StringUtils.fromString("name");
    public static final BString EXTENSION = StringUtils.fromString("extension");
    public static final BString IS_HIDDEN = StringUtils.fromString("isHidden");
    public static final BString IS_WRITABLE = StringUtils.fromString("isWritable");
    public static final BString IS_DIRECTORY = StringUtils.fromString("isDirectory");
    public static final BString IS_EXECUTABLE = StringUtils.fromString("isExecutable");
    public static final BString URI = StringUtils.fromString("uri");
    public static final String KERBEROS_AUTH_CONTEXT_ERROR = "Failed to create Kerberos authentication context: ";
    public static final String REMOVE_DIRECTORY_ERROR = "Failed to remove directory: ";
    public static final String RENAME_FILE_ERROR = "Failed to rename file: ";
    public static final String IS_DIRECTORY_ERROR = "Failed to validate the directory path: ";
    public static final String WRITE_FILE_ERROR = "Failed to write file: ";
    public static final String DELETE_FILE_ERROR = "Failed to delete file: ";
    public static final String WRITE_CSV_FILE_ERROR = "Failed to write CSV file: ";
    public static final String WRITE_XML_FILE_ERROR = "Failed to write XML file: ";
    public static final String GET_FILE_SIZE_ERROR = "Failed to get file size: ";
    public static final String FILE_EXISTENCE_ERROR = "Failed to check file existence: ";
    public static final String COPY_FILE_ERROR = "Failed to copy file: ";

    private SmbClient() {
    }

    public static Object initClientEndpoint(BObject clientEndpoint, BMap<Object, Object> config) {
        try {
            String host = config.getStringValue(StringUtils.fromString(ENDPOINT_CONFIG_HOST)).getValue();
            String share = config.getStringValue(StringUtils.fromString(ENDPOINT_CONFIG_SHARE)).getValue();
            int port = config.getIntValue(StringUtils.fromString(ENDPOINT_CONFIG_PORT)).intValue();
            BMap<?, ?> authConfig = config.getMapValue(StringUtils.fromString(ENDPOINT_CONFIG_AUTH));
            String authType = AUTH_TYPE_ANONYMOUS;
            if (authConfig != null) {
                BMap<?, ?> credentials = authConfig.getMapValue(StringUtils.fromString(ENDPOINT_CONFIG_CREDENTIALS));
                BMap<?, ?> kerberosConfig = authConfig.getMapValue(StringUtils.fromString(KERBEROS_CONFIG));
                if (credentials == null && kerberosConfig == null) {
                    return SmbUtil.createError(MISSING_CREDENTIALS_FOR_AUTH_ERROR, SMB_ERROR);
                }
                if (kerberosConfig != null && credentials == null) {
                    BString keytabValue = kerberosConfig.getStringValue(StringUtils.fromString(KERBEROS_KEYTAB));
                    boolean hasKeytab = keytabValue != null && !keytabValue.getValue().isEmpty();
                    if (!hasKeytab) {
                        return SmbUtil.createError(MISSING_CREDENTIALS_FOR_KERBEROS_ERROR, SMB_ERROR);
                    }
                }
                if (credentials != null) {
                    String username =
                            credentials.getStringValue(StringUtils.fromString(ENDPOINT_CONFIG_USERNAME)).getValue();
                    String password =
                            credentials.getStringValue(StringUtils.fromString(ENDPOINT_CONFIG_PASS_KEY)).getValue();
                    String domain =
                            credentials.getStringValue(StringUtils.fromString(ENDPOINT_CONFIG_DOMAIN)).getValue();
                    clientEndpoint.addNativeData(ENDPOINT_CONFIG_USERNAME, username);
                    clientEndpoint.addNativeData(ENDPOINT_CONFIG_PASS_KEY, password);
                    clientEndpoint.addNativeData(ENDPOINT_CONFIG_DOMAIN, domain);
                }
                clientEndpoint.addNativeData(KERBEROS_CONFIG, kerberosConfig);
                authType = kerberosConfig != null ? AUTH_TYPE_KERBEROS : AUTH_TYPE_NTLM;
            }
            BArray dialectsArray = config.getArrayValue(StringUtils.fromString(ENDPOINT_CONFIG_DIALECTS));
            boolean signRequired = config.getBooleanValue(StringUtils.fromString(ENDPOINT_CONFIG_SIGN_REQUIRED));
            boolean encryptData = config.getBooleanValue(StringUtils.fromString(ENDPOINT_CONFIG_ENCRYPT_DATA));
            boolean enableDfs = config.getBooleanValue(StringUtils.fromString(ENDPOINT_CONFIG_ENABLE_DFS));
            int bufferSize = config.getIntValue(StringUtils.fromString(ENDPOINT_CONFIG_BUFFER_SIZE)).intValue();
            BDecimal connectTimeout = (BDecimal) config.get(StringUtils.fromString(ENDPOINT_CONFIG_CONNECT_TIMEOUT));
            
            clientEndpoint.addNativeData(ENDPOINT_CONFIG_HOST, host);
            clientEndpoint.addNativeData(ENDPOINT_CONFIG_SHARE, share);
            clientEndpoint.addNativeData(ENDPOINT_CONFIG_PORT, port);
            clientEndpoint.addNativeData(AUTH_TYPE, authType);
            clientEndpoint.addNativeData(ENDPOINT_CONFIG_BUFFER_SIZE, bufferSize);
            clientEndpoint.addNativeData(ENDPOINT_CONFIG_LAX_DATA_BINDING,
                    config.getBooleanValue(StringUtils.fromString(ENDPOINT_CONFIG_LAX_DATA_BINDING)));
            clientEndpoint.addNativeData(ENDPOINT_CONFIG_CSV_FAIL_SAFE,
                    config.getMapValue(StringUtils.fromString(ENDPOINT_CONFIG_CSV_FAIL_SAFE)));
            
            boolean isAnonymous = authType.equals(AUTH_TYPE_ANONYMOUS);
            boolean effectiveEncryptData = !isAnonymous && encryptData;
            boolean effectiveSignRequired = !isAnonymous && signRequired;
            SmbConfig.Builder configBuilder = SmbConfig.builder()
                    .withTimeout(connectTimeout.intValue(), TimeUnit.SECONDS)
                    .withSigningRequired(effectiveSignRequired)
                    .withEncryptData(effectiveEncryptData)
                    .withDfsEnabled(enableDfs);
            if (dialectsArray.size() <= 0) {
                return SmbUtil.createError(DIALECT_NOT_SPECIFIED_ERROR, SMB_ERROR);
            }
            List<SMB2Dialect> dialectList = IntStream.range(0, dialectsArray.size())
                    .mapToObj(i -> mapDialect(dialectsArray.getBString(i).getValue()))
                    .filter(dialect -> !isAnonymous ||
                            dialect == SMB2Dialect.SMB_2_0_2 || dialect == SMB2Dialect.SMB_2_1)
                    .collect(Collectors.toList());

            if (isAnonymous && dialectList.isEmpty()) {
                dialectList.add(SMB2Dialect.SMB_2_1);
                dialectList.add(SMB2Dialect.SMB_2_0_2);
            }
            SMB2Dialect[] dialects = dialectList.toArray(new SMB2Dialect[0]);
            configBuilder.withDialects(dialects);
            SMBClient smbClient = new SMBClient(configBuilder.build());
            clientEndpoint.addNativeData(SMB_CLIENT_CONNECTOR, smbClient);
            
            Connection connection = smbClient.connect(host, port);
            Session session = authenticateSession(connection, clientEndpoint);
            DiskShare diskShare = (DiskShare) session.connectShare(share);
            clientEndpoint.addNativeData(SMB_CONNECTION, connection);
            clientEndpoint.addNativeData(SMB_SESSION, session);
            clientEndpoint.addNativeData(SMB_SHARE, diskShare);

            log.debug("SMB client initialized successfully for host: {} share: {}", host, share);
            return null;
        } catch (Exception exception) {
            return SmbUtil.createError(CLIENT_INITIALIZATION_ERROR + exception.getMessage(), SMB_ERROR);
        }
    }

    public static Object mkdir(Environment env, BObject clientEndpoint, BString directoryPath) {
        return env.yieldAndRun(() -> {
            try {
                DiskShare share = retrieveShare(clientEndpoint);
                share.mkdir(directoryPath.getValue());
                return null;
            } catch (Exception exception) {
                return SmbUtil.createError(DIRECTORY_CREATE_ERROR + exception.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object put(Environment env, BObject clientEndpoint, BString path, BArray inputContent) {
        return env.yieldAndRun(() -> {
            try {
                writeFileBytes(clientEndpoint, path.getValue(),  inputContent.getByteArray(), false);
            } catch (Exception exception) {
                return SmbUtil.createError(FILE_WRITE_ERROR + exception.getMessage(), SMB_ERROR);
            }
            return null;
        });
    }

    public static Object list(Environment env, BObject clientEndpoint, BString directoryPath) {
        return env.yieldAndRun(() -> {
            try {
                DiskShare share = retrieveShare(clientEndpoint);
                List<FileIdBothDirectoryInformation> files = share.list(directoryPath.getValue());
                List<BMap<BString, Object>> fileInfoList = new ArrayList<>();

                for (FileIdBothDirectoryInformation fileInfo : files) {
                    String fileName = fileInfo.getFileName();
                    if (".".equals(fileName) || "..".equals(fileName)) {
                        continue;
                    }
                    BMap<BString, Object> fileInfoRecord = ValueCreator.createRecordValue(
                            ModuleUtils.getModule(), FILE_INFO_TYPE);
                    String fullPath = directoryPath.getValue();
                    if (!fullPath.endsWith("/")) {
                        fullPath += "/";
                    }
                    fullPath += fileName;

                    String extension = "";
                    int lastDot = fileName.lastIndexOf('.');
                    if (lastDot > 0) {
                        extension = fileName.substring(lastDot + 1);
                    }

                    long fileAttributes = fileInfo.getFileAttributes();
                    boolean isFolder = EnumWithValue.EnumUtils.isSet(fileAttributes,
                            FileAttributes.FILE_ATTRIBUTE_DIRECTORY);
                    boolean isHidden = EnumWithValue.EnumUtils.isSet(fileAttributes,
                            FileAttributes.FILE_ATTRIBUTE_HIDDEN);
                    boolean isReadOnly = EnumWithValue.EnumUtils.isSet(fileAttributes,
                            FileAttributes.FILE_ATTRIBUTE_READONLY);

                    fileInfoRecord.put(PATH, StringUtils.fromString(fullPath));
                    fileInfoRecord.put(SIZE, fileInfo.getEndOfFile());
                    fileInfoRecord.put(MODIFIED_AT, createUtcTuple(fileInfo.getChangeTime().toEpochMillis()));
                    fileInfoRecord.put(CREATED_AT, createUtcTuple(fileInfo.getCreationTime().toEpochMillis()));
                    fileInfoRecord.put(ACCESSED_AT, createUtcTuple(fileInfo.getLastAccessTime().toEpochMillis()));
                    fileInfoRecord.put(WRITTEN_AT, createUtcTuple(fileInfo.getLastWriteTime().toEpochMillis()));
                    fileInfoRecord.put(NAME, StringUtils.fromString(fileName));
                    fileInfoRecord.put(IS_DIRECTORY, isFolder);
                    fileInfoRecord.put(EXTENSION, StringUtils.fromString(extension));
                    fileInfoRecord.put(IS_EXECUTABLE, !isFolder && isExecutableFile(fileName));
                    fileInfoRecord.put(IS_HIDDEN, isHidden);
                    fileInfoRecord.put(IS_WRITABLE, !isReadOnly);
                    fileInfoRecord.put(URI, StringUtils.fromString(fullPath));
                    fileInfoList.add(fileInfoRecord);
                }

                ArrayType arrayType = TypeCreator.createArrayType(
                        TypeCreator.createRecordType(FILE_INFO_TYPE, ModuleUtils.getModule(), 0, false, 0));
                BArray fileInfoArray = ValueCreator.createArrayValue(
                        fileInfoList.toArray(new BMap[0]), arrayType);
                log.debug("Listed {} items in directory: {}", fileInfoList.size(), directoryPath);
                return fileInfoArray;
            } catch (Exception e) {
                return SmbUtil.createError("Failed to list directory: " + e.getMessage(), SMB_ERROR);
            }
        });
    }

    private static SMB2Dialect mapDialect(String dialectStr) {
        switch (dialectStr) {
            case DIALECT_SMB_3_1_1 -> {
                return SMB2Dialect.SMB_3_1_1;
            }
            case DIALECT_SMB_3_0 -> {
                return SMB2Dialect.SMB_3_0;
            }
            case DIALECT_SMB_2_1 -> {
                return SMB2Dialect.SMB_2_1;
            }
            case DIALECT_SMB_2_0_2 -> {
                return SMB2Dialect.SMB_2_0_2;
            }
            default -> {
                return SMB2Dialect.SMB_3_0_2;
            }
        }
    }

    public static Object getBytes(Environment env, BObject clientEndpoint, BString filePath) {
        return env.yieldAndRun(() -> {
            try {
                byte[] getBytesResult = readFileAsBytes(clientEndpoint, filePath.getValue());
                return ValueCreator.createArrayValue(getBytesResult);
            } catch (Exception e) {
                return SmbUtil.createError("Failed to read file: " + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object getText(Environment env, BObject clientEndpoint, BString filePath) {
        return env.yieldAndRun(() -> {
            try {
                byte[] bytes = readFileAsBytes(clientEndpoint, filePath.getValue());
                return StringUtils.fromString(new String(bytes, StandardCharsets.UTF_8));
            } catch (Exception e) {
                return SmbUtil.createError("Failed to read file as text: " + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object getJson(Environment env, BObject clientEndpoint, BString filePath,
                                  io.ballerina.runtime.api.values.BTypedesc typeDesc) {
        return env.yieldAndRun(() -> {
            try {
                byte[] bytes = readFileAsBytes(clientEndpoint, filePath.getValue());
                boolean laxDataBinding = (boolean) clientEndpoint.getNativeData(ENDPOINT_CONFIG_LAX_DATA_BINDING);
                return SmbContentConverter.convertBytesToJson(bytes, typeDesc.getDescribingType(), laxDataBinding);
            } catch (Exception e) {
                return SmbUtil.createError("Failed to read file as JSON: " + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object getXml(Environment env, BObject clientEndpoint, BString filePath,
                                 io.ballerina.runtime.api.values.BTypedesc typeDesc) {
        return env.yieldAndRun(() -> {
            try {
                byte[] bytes = readFileAsBytes(clientEndpoint, filePath.getValue());
                boolean laxDataBinding = (boolean) clientEndpoint.getNativeData(ENDPOINT_CONFIG_LAX_DATA_BINDING);
                return SmbContentConverter.convertBytesToXml(bytes, typeDesc.getDescribingType(), laxDataBinding);
            } catch (Exception e) {
                return SmbUtil.createError("Failed to read file as XML: " + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object getCsv(Environment env, BObject clientEndpoint, BString filePath,
                                 io.ballerina.runtime.api.values.BTypedesc typeDesc) {
        return env.yieldAndRun(() -> {
            try {
                byte[] bytes = readFileAsBytes(clientEndpoint, filePath.getValue());
                boolean laxDataBinding = (boolean) clientEndpoint.getNativeData(ENDPOINT_CONFIG_LAX_DATA_BINDING);
                BMap<?, ?> csvFailSafe = (BMap<?, ?>) clientEndpoint.getNativeData(ENDPOINT_CONFIG_CSV_FAIL_SAFE);
                String fileNamePrefix = SmbContentConverter.deriveFileNamePrefix(filePath);
                return SmbContentConverter.convertBytesToCsv(env, bytes, typeDesc.getDescribingType(),
                        laxDataBinding, csvFailSafe, fileNamePrefix);
            } catch (Exception e) {
                return SmbUtil.createError("Failed to read file as CSV: " + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object getBytesAsStream(Environment env, BObject clientEndpoint, BString filePath) {
        return env.yieldAndRun(() -> {
            try {
                SMBClient smbClient = (SMBClient) clientEndpoint.getNativeData(SMB_CLIENT_CONNECTOR);
                if (smbClient == null) {
                    return SmbUtil.createError(CLIENT_CLOSED_ERROR_MESSAGE, SMB_ERROR);
                }
                boolean laxDataBinding = (boolean) clientEndpoint.getNativeData(ENDPOINT_CONFIG_LAX_DATA_BINDING);
                InputStream inputStream = getFileInputStream(clientEndpoint, filePath.getValue());
                Type streamValueType = TypeCreator.createArrayType(PredefinedTypes.TYPE_BYTE);
                return createByteStream(inputStream, streamValueType, laxDataBinding);
            } catch (Exception e) {
                return SmbUtil.createError("Failed to read file as byte stream: " + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object getCsvAsStream(Environment env, BObject clientEndpoint, BString filePath,
                                        BTypedesc typeDesc) {
        return env.yieldAndRun(() -> {
            try {
                SMBClient smbClient = (SMBClient) clientEndpoint.getNativeData(SMB_CLIENT_CONNECTOR);
                if (smbClient == null) {
                    return SmbUtil.createError(CLIENT_CLOSED_ERROR_MESSAGE, SMB_ERROR);
                }
                boolean laxDataBinding = (boolean) clientEndpoint.getNativeData(ENDPOINT_CONFIG_LAX_DATA_BINDING);
                InputStream inputStream = getFileInputStream(clientEndpoint, filePath.getValue());
                Type streamValueType = typeDesc.getDescribingType();
                return createCsvStream(inputStream, streamValueType, laxDataBinding);
            } catch (Exception e) {
                return SmbUtil.createError("Failed to read file as CSV stream: " + e.getMessage(), SMB_ERROR);
            }
        });
    }

    private static InputStream getFileInputStream(BObject clientEndpoint, String filePath) throws IOException {
        DiskShare share = retrieveShare(clientEndpoint);
        Set<AccessMask> accessMask = new HashSet<>();
        accessMask.add(AccessMask.GENERIC_READ);
        File file = share.openFile(filePath, accessMask, null,
                SMB2ShareAccess.ALL, SMB2CreateDisposition.FILE_OPEN, null);
        return file.getInputStream();
    }

    private static Object createByteStream(InputStream content, Type streamValueType, boolean laxDataBinding) {
        BObject contentByteStreamObject = ValueCreator.createObjectValue(
                ModuleUtils.getModule(), "ContentByteStream", null, null);
        contentByteStreamObject.addNativeData(ByteIterator.NATIVE_INPUT_STREAM, content);
        contentByteStreamObject.addNativeData(ByteIterator.NATIVE_LAX_DATA_BINDING, laxDataBinding);
        contentByteStreamObject.addNativeData(ByteIterator.NATIVE_STREAM_VALUE_TYPE, streamValueType);
        return ValueCreator.createStreamValue(TypeCreator.createStreamType(streamValueType,
                TypeCreator.createUnionType(PredefinedTypes.TYPE_ERROR, PredefinedTypes.TYPE_NULL)),
                contentByteStreamObject);
    }

    private static Object createCsvStream(InputStream content, Type streamValueType, boolean laxDataBinding) {
        if (streamValueType.getTag() == TypeTags.ARRAY_TAG) {
            ArrayType arrayType = (ArrayType) streamValueType;
            if (arrayType.getElementType().getTag() == TypeTags.STRING_TAG) {
                return CsvIterator.createStringArrayStream(content, streamValueType, laxDataBinding);
            }
        }
        return CsvIterator.createRecordStream(content, streamValueType, laxDataBinding);
    }

    public static Object putBytes(Environment env, BObject clientEndpoint, BString filePath,
                                   BArray content, BString option) {
        return env.yieldAndRun(() -> {
            try {
                byte[] bytes = content.getBytes();
                boolean append = WRITE_OPTION_APPEND.equals(option.getValue());
                writeFileBytes(clientEndpoint, filePath.getValue(), bytes, append);
                return null;
            } catch (Exception e) {
                return SmbUtil.createError(WRITE_FILE_ERROR + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object patch(Environment env, BObject clientEndpoint, BString filePath,
                                BArray content, long offset) {
        return env.yieldAndRun(() -> {
            try {
                DiskShare share = retrieveShare(clientEndpoint);
                Set<AccessMask> accessMask = new HashSet<>();
                accessMask.add(AccessMask.GENERIC_WRITE);
                accessMask.add(AccessMask.GENERIC_READ);
                Set<FileAttributes> fileAttributes = new HashSet<>();
                fileAttributes.add(FileAttributes.FILE_ATTRIBUTE_NORMAL);
                File file = share.openFile(filePath.getValue(), accessMask, fileAttributes,
                        SMB2ShareAccess.ALL, SMB2CreateDisposition.FILE_OPEN_IF,
                        EnumSet.noneOf(SMB2CreateOptions.class));
                byte[] bytes = content.getBytes();
                file.write(bytes, offset);
                file.flush();
                file.close();
                return null;
            } catch (Exception e) {
                return SmbUtil.createError("Failed to patch file: " + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object putText(Environment env, BObject clientEndpoint, BString filePath,
                                  BString content, BString option) {
        return env.yieldAndRun(() -> {
            try {
                byte[] bytes = content.getValue().getBytes(StandardCharsets.UTF_8);
                boolean append = WRITE_OPTION_APPEND.equals(option.getValue());
                writeFileBytes(clientEndpoint, filePath.getValue(), bytes, append);
                return null;
            } catch (Exception e) {
                return SmbUtil.createError(WRITE_FILE_ERROR + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object delete(Environment env, BObject clientEndpoint, BString filePath) {
        return env.yieldAndRun(() -> {
            try {
                DiskShare share = retrieveShare(clientEndpoint);
                share.rm(filePath.getValue());
                return null;
            } catch (Exception e) {
                return SmbUtil.createError(DELETE_FILE_ERROR + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object close(BObject clientEndpoint) {
        try {
            DiskShare share = (DiskShare) clientEndpoint.getNativeData(SMB_SHARE);
            if (share != null) {
                share.close();
                clientEndpoint.addNativeData(SMB_SHARE, null);
            }
            Session session = (Session) clientEndpoint.getNativeData(SMB_SESSION);
            if (session != null) {
                session.close();
                clientEndpoint.addNativeData(SMB_SESSION, null);
            }
            Connection connection = (Connection) clientEndpoint.getNativeData(SMB_CONNECTION);
            if (connection != null) {
                connection.close();
                clientEndpoint.addNativeData(SMB_CONNECTION, null);
            }
            SMBClient smbClient = (SMBClient) clientEndpoint.getNativeData(SMB_CLIENT_CONNECTOR);
            if (smbClient != null) {
                smbClient.close();
                clientEndpoint.addNativeData(SMB_CLIENT_CONNECTOR, null);
            }
            return null;
        } catch (Exception e) {
            return SmbUtil.createError(ON_CLOSE_ERROR + e.getMessage(), SMB_ERROR);
        }
    }

    private static byte[] readFileAsBytes(BObject clientEndpoint, String filePath) throws IOException {
        DiskShare share = retrieveShare(clientEndpoint);
        Set<AccessMask> accessMask = new HashSet<>();
        accessMask.add(AccessMask.GENERIC_READ);
        File file = share.openFile(filePath, accessMask, null,
                SMB2ShareAccess.ALL, SMB2CreateDisposition.FILE_OPEN, null);
        InputStream inputStream = file.getInputStream();
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        byte[] buffer = new byte[ARRAY_SIZE];
        int bytesRead;
        while ((bytesRead = inputStream.read(buffer)) != -1) {
            outputStream.write(buffer, 0, bytesRead);
        }
        return outputStream.toByteArray();
    }

    private static void writeFileBytes(BObject clientEndpoint, String filePath,
                                       byte[] bytes, boolean append) throws IOException {
        DiskShare share = retrieveShare(clientEndpoint);
        Set<AccessMask> accessMask = new HashSet<>();
        accessMask.add(AccessMask.GENERIC_WRITE);

        Set<FileAttributes> fileAttributes = new HashSet<>();
        fileAttributes.add(FileAttributes.FILE_ATTRIBUTE_NORMAL);

        SMB2CreateDisposition disposition = append ?
                SMB2CreateDisposition.FILE_OPEN_IF : SMB2CreateDisposition.FILE_OVERWRITE_IF;

        File file = share.openFile(filePath, accessMask, fileAttributes, SMB2ShareAccess.ALL,
                disposition, EnumSet.noneOf(SMB2CreateOptions.class));
        OutputStream outputStream = file.getOutputStream(append);
        outputStream.write(bytes);
        outputStream.flush();
    }

    private static Session authenticateSession(Connection connection, BObject clientEndpoint) throws IOException {
        String authType = (String) clientEndpoint.getNativeData(AUTH_TYPE);
        AuthenticationContext authContext;
        if (authType.equals(AUTH_TYPE_ANONYMOUS)) {
            authContext = AuthenticationContext.anonymous();
        } else if (authType.equals(AUTH_TYPE_KERBEROS)) {
            Object passwordObj = clientEndpoint.getNativeData(ENDPOINT_CONFIG_PASS_KEY);
            Object domainObj = clientEndpoint.getNativeData(ENDPOINT_CONFIG_DOMAIN);
            String password = passwordObj != null ? passwordObj.toString() : null;
            String domain = domainObj != null ? domainObj.toString() : null;
            authContext = createKerberosAuthContext(clientEndpoint, password, domain);
        } else {
            String username = clientEndpoint.getNativeData(ENDPOINT_CONFIG_USERNAME).toString();
            String password = clientEndpoint.getNativeData(ENDPOINT_CONFIG_PASS_KEY).toString();
            String domain = clientEndpoint.getNativeData(ENDPOINT_CONFIG_DOMAIN).toString();
            authContext = new AuthenticationContext(username, password.toCharArray(), domain);
        }
        return connection.authenticate(authContext);
    }

    private static AuthenticationContext createKerberosAuthContext(BObject clientEndpoint,
                                                                   String password, String domain) throws IOException {
        try {
            BMap<?, ?> kerberosConfig = (BMap<?, ?>) clientEndpoint.getNativeData(KERBEROS_CONFIG);
            String principal = kerberosConfig.getStringValue(StringUtils.fromString(KERBEROS_PRINCIPAL)).getValue();
            BString keytabValue = kerberosConfig.getStringValue(StringUtils.fromString(KERBEROS_KEYTAB));
            String keytabPath = keytabValue != null ? keytabValue.getValue() : null;
            BString configFileValue = kerberosConfig.getStringValue(StringUtils.fromString(KERBEROS_CONFIG_FILE));
            String configFile = configFileValue != null ? configFileValue.getValue() : null;

            String realm = principal.substring(principal.indexOf('@') + 1);
            String kerberosUsername = principal.substring(0, principal.indexOf('@'));
            setKerberosSystemProperties(configFile);

            Subject subject = (keytabPath != null && !keytabPath.isEmpty())
                    ? loginWithKeytab(principal, keytabPath)
                    : (password != null && !password.isEmpty())
                    ? loginWithPassword(principal, password)
                    : loginWithTicketCache(principal);
            return new GSSAuthenticationContext(kerberosUsername, realm, subject, null);
        } catch (Exception e) {
            throw new IOException(KERBEROS_AUTH_CONTEXT_ERROR + e.getMessage(), e);
        }
    }

    private static void setKerberosSystemProperties(String configFile) {
        if (configFile != null && !configFile.isEmpty()) {
            System.setProperty("java.security.krb5.conf", configFile);
        }
        System.setProperty("javax.security.auth.useSubjectCredsOnly", "false");
    }

    private static Subject loginWithKeytab(String principal, String keytabPath) throws LoginException {
        Configuration jaasConfig = new Configuration() {
            @Override
            public AppConfigurationEntry[] getAppConfigurationEntry(String name) {
                Map<String, String> options = new HashMap<>();
                options.put("useKeyTab", "true");
                options.put("keyTab", keytabPath);
                options.put("storeKey", "true");
                options.put("doNotPrompt", "true");
                options.put("principal", principal);
                options.put("debug", String.valueOf(log.isDebugEnabled()));

                return new AppConfigurationEntry[]{
                        new AppConfigurationEntry("com.sun.security.auth.module.Krb5LoginModule",
                                AppConfigurationEntry.LoginModuleControlFlag.REQUIRED, options
                        )
                };
            }
        };
        LoginContext loginContext = new LoginContext("SmbKerberosClient", null, null, jaasConfig);
        loginContext.login();
        return loginContext.getSubject();
    }

    private static Subject loginWithPassword(String principal, String password) throws LoginException {
        Configuration jaasConfig = new Configuration() {
            @Override
            public AppConfigurationEntry[] getAppConfigurationEntry(String name) {
                Map<String, String> options = new HashMap<>();
                options.put("useTicketCache", "false");
                options.put("renewTGT", "false");
                options.put("doNotPrompt", "false");
                options.put("storeKey", "true");
                options.put("debug", String.valueOf(log.isDebugEnabled()));

                return new AppConfigurationEntry[]{
                        new AppConfigurationEntry(
                                "com.sun.security.auth.module.Krb5LoginModule",
                                AppConfigurationEntry.LoginModuleControlFlag.REQUIRED,
                                options
                        )
                };
            }
        };

        CallbackHandler callbackHandler = callbacks -> {
            for (Callback callback : callbacks) {
                if (callback instanceof NameCallback) {
                    ((NameCallback) callback).setName(principal);
                } else if (callback instanceof PasswordCallback) {
                    ((PasswordCallback) callback).setPassword(password.toCharArray());
                }
            }
        };

        LoginContext loginContext = new LoginContext("SmbKerberosClient", null, callbackHandler, jaasConfig);
        loginContext.login();
        return loginContext.getSubject();
    }

    private static Subject loginWithTicketCache(String principal) throws LoginException {
        Configuration jaasConfig = new Configuration() {
            @Override
            public AppConfigurationEntry[] getAppConfigurationEntry(String name) {
                Map<String, String> options = new HashMap<>();
                options.put("useTicketCache", "true");
                options.put("renewTGT", "true");
                options.put("doNotPrompt", "true");
                options.put("storeKey", "false");
                options.put("principal", principal);
                options.put("debug", String.valueOf(log.isDebugEnabled()));

                return new AppConfigurationEntry[]{
                        new AppConfigurationEntry(
                                "com.sun.security.auth.module.Krb5LoginModule",
                                AppConfigurationEntry.LoginModuleControlFlag.REQUIRED,
                                options
                        )
                };
            }
        };

        LoginContext loginContext = new LoginContext("SmbKerberosClient", null, null, jaasConfig);
        loginContext.login();
        return loginContext.getSubject();
    }

    private static DiskShare retrieveShare(BObject clientEndpoint) throws IOException {
        SMBClient smbClient = (SMBClient) clientEndpoint.getNativeData(SMB_CLIENT_CONNECTOR);
        if (smbClient == null) {
            throw new IOException(CLIENT_CLOSED_ERROR_MESSAGE);
        }
        DiskShare share = (DiskShare) clientEndpoint.getNativeData(SMB_SHARE);
        Connection connection = (Connection) clientEndpoint.getNativeData(SMB_CONNECTION);
        if (share != null && share.isConnected()) {
            return share;
        }
        if (connection != null) {
            connection.close();
        }
        return reconnectShare(clientEndpoint, smbClient);
    }

    private static DiskShare reconnectShare(BObject clientEndpoint,
                                            SMBClient smbClient) throws IOException {
        String host = (String) clientEndpoint.getNativeData(ENDPOINT_CONFIG_HOST);
        int port = (Integer) clientEndpoint.getNativeData(ENDPOINT_CONFIG_PORT);
        String shareName = (String) clientEndpoint.getNativeData(ENDPOINT_CONFIG_SHARE);

        Connection connection = smbClient.connect(host, port);
        Session session = authenticateSession(connection, clientEndpoint);
        DiskShare share = (DiskShare) session.connectShare(shareName);

        clientEndpoint.addNativeData(SMB_CONNECTION, connection);
        clientEndpoint.addNativeData(SMB_SESSION, session);
        clientEndpoint.addNativeData(SMB_SHARE, share);
        return share;
    }

    public static Object rmdir(Environment env, BObject clientEndpoint, BString directoryPath) {
        return env.yieldAndRun(() -> {
            try {
                DiskShare share = retrieveShare(clientEndpoint);
                share.rmdir(directoryPath.getValue(), true);
                return null;
            } catch (Exception e) {
                return SmbUtil.createError(REMOVE_DIRECTORY_ERROR + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object rename(Environment env, BObject clientEndpoint, BString origin, BString destination) {
        return env.yieldAndRun(() -> {
            try {
                DiskShare share = retrieveShare(clientEndpoint);
                byte[] content = readFileContentFromShare(share, origin.getValue());
                writeFileContentToShare(share, destination.getValue(), content, false);
                share.rm(origin.getValue());
                return null;
            } catch (Exception e) {
                return SmbUtil.createError(RENAME_FILE_ERROR + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object move(Environment env, BObject clientEndpoint, BString sourcePath, BString destinationPath) {
        return rename(env, clientEndpoint, sourcePath, destinationPath);
    }

    public static Object copy(Environment env, BObject clientEndpoint, BString sourcePath, BString destinationPath) {
        return env.yieldAndRun(() -> {
            try {
                DiskShare share = retrieveShare(clientEndpoint);
                byte[] content = readFileContentFromShare(share, sourcePath.getValue());
                writeFileContentToShare(share, destinationPath.getValue(), content, false);
                return null;
            } catch (Exception e) {
                return SmbUtil.createError(COPY_FILE_ERROR + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object exists(Environment env, BObject clientEndpoint, BString path) {
        return env.yieldAndRun(() -> {
            try {
                DiskShare share = retrieveShare(clientEndpoint);
                return share.fileExists(path.getValue()) || share.folderExists(path.getValue());
            } catch (Exception e) {
                return SmbUtil.createError(FILE_EXISTENCE_ERROR + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object size(Environment env, BObject clientEndpoint, BString filePath) {
        return env.yieldAndRun(() -> {
            try {
                DiskShare share = retrieveShare(clientEndpoint);
                FileAllInformation fileInfo = share.getFileInformation(filePath.getValue());
                return fileInfo.getStandardInformation().getEndOfFile();
            } catch (Exception e) {
                return SmbUtil.createError(GET_FILE_SIZE_ERROR + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object isDirectory(Environment env, BObject clientEndpoint, BString path) {
        return env.yieldAndRun(() -> {
            try {
                DiskShare share = retrieveShare(clientEndpoint);
                return share.folderExists(path.getValue());
            } catch (Exception e) {
                return SmbUtil.createError(IS_DIRECTORY_ERROR + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object putJson(Environment env, BObject clientEndpoint, BString filePath, 
                                 BString content, BString option) {
        return putText(env, clientEndpoint, filePath, content, option);
    }

    public static Object putXml(Environment env, BObject clientEndpoint, BString filePath,
                                 BString content, BString option) {
        return env.yieldAndRun(() -> {
            try {
                byte[] bytes = content.getValue().getBytes(StandardCharsets.UTF_8);
                boolean append = WRITE_OPTION_APPEND.equals(option.getValue());
                writeFileBytes(clientEndpoint, filePath.getValue(), bytes, append);
                return null;
            } catch (Exception e) {
                return SmbUtil.createError(WRITE_XML_FILE_ERROR + e.getMessage(), SMB_ERROR);
            }
        });
    }

    public static Object putCsv(Environment env, BObject clientEndpoint, BString filePath,
                                 BArray content, BString option) {
        return env.yieldAndRun(() -> {
            try {
                boolean addHeader = !option.getValue().equals(WRITE_OPTION_APPEND);
                String convertToCsv = CSVUtils.convertToCsv(content, addHeader);
                byte[] bytes = convertToCsv.getBytes(StandardCharsets.UTF_8);
                boolean append = WRITE_OPTION_APPEND.equals(option.getValue());
                writeFileBytes(clientEndpoint, filePath.getValue(), bytes, append);
                return null;
            } catch (Exception e) {
                return SmbUtil.createError(WRITE_CSV_FILE_ERROR + e.getMessage(), SMB_ERROR);
            }
        });
    }

    private static byte[] readFileContentFromShare(DiskShare share, String filePath) throws IOException {
        Set<AccessMask> accessMask = new HashSet<>();
        accessMask.add(AccessMask.GENERIC_READ);
        File file = share.openFile(filePath, accessMask, null, SMB2ShareAccess.ALL,
                SMB2CreateDisposition.FILE_OPEN, null);
        InputStream inputStream = file.getInputStream();
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
        byte[] buffer = new byte[ARRAY_SIZE];
        int bytesRead;
        while ((bytesRead = inputStream.read(buffer)) != -1) {
            outputStream.write(buffer, 0, bytesRead);
        }
        return outputStream.toByteArray();
    }

    private static void writeFileContentToShare(DiskShare share, String filePath,
                                                byte[] bytes, boolean append) throws IOException {
        Set<AccessMask> accessMask = new HashSet<>();
        accessMask.add(AccessMask.GENERIC_WRITE);
        Set<FileAttributes> fileAttributes = new HashSet<>();
        fileAttributes.add(FileAttributes.FILE_ATTRIBUTE_NORMAL);
        SMB2CreateDisposition disposition = append ?
                SMB2CreateDisposition.FILE_OPEN_IF : SMB2CreateDisposition.FILE_OVERWRITE_IF;
        File file = share.openFile(filePath, accessMask, fileAttributes, SMB2ShareAccess.ALL,
                disposition, EnumSet.noneOf(SMB2CreateOptions.class));
        OutputStream outputStream = file.getOutputStream(append);
        outputStream.write(bytes);
        outputStream.flush();
    }

    private static boolean isExecutableFile(String fileName) {
        int lastDot = fileName.lastIndexOf('.');
        if (lastDot <= 0) {
            return false;
        }
        String extension = fileName.substring(lastDot + 1).toLowerCase();
        return EXECUTABLE_EXTENSIONS.contains(extension);
    }

    private static BArray createUtcTuple(long epochMillis) {
        long seconds = epochMillis / 1000;
        long remainingMillis = epochMillis % 1000;
        BigDecimal fraction = new BigDecimal(remainingMillis).movePointLeft(3);
        TupleType utcTupleType = TypeCreator.createTupleType(
                List.of(PredefinedTypes.TYPE_INT, PredefinedTypes.TYPE_DECIMAL));
        BArray timeData = ValueCreator.createTupleValue(utcTupleType);
        timeData.add(0, seconds);
        timeData.add(1, ValueCreator.createDecimalValue(fraction));
        return timeData;
    }
}

