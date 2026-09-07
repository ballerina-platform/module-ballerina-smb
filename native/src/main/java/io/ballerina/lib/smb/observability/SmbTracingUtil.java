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

package io.ballerina.lib.smb.observability;

import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.observability.ObservabilityConstants;
import io.ballerina.runtime.observability.ObserveUtils;
import io.ballerina.runtime.observability.ObserverContext;
import io.ballerina.runtime.observability.tracer.BSpan;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

/**
 * Utility class for injecting SMB observability context into Ballerina strands and spans.
 *
 * <p>Two usage patterns:
 * <ul>
 *   <li><b>Listener dispatch</b> — call {@link #createStrandProperties} to build a properties map
 *       that is embedded in {@code StrandMetadata} when dispatching a service method via
 *       {@code callMethod}.</li>
 *   <li><b>Client operations</b> — call {@link #sendMetricsData} from inside a native external
 *       method to enrich the auto-instrumented span with SMB-specific tags.</li>
 * </ul>
 */
public class SmbTracingUtil {

    private static final Logger log = LoggerFactory.getLogger(SmbTracingUtil.class);

    private SmbTracingUtil() {
    }

    /**
     * Creates a per-file parent span that covers the entire file lifecycle (found → cleaned_up).
     *
     * @param url      host:port of the remote server
     * @param protocol the wire protocol
     * @param filePath path of the file being processed (added as a trace-only tag)
     * @return context with parent span, or {@code null} if observability is disabled
     */
    public static SmbObserverContext createFileLifecycleContext(String url, String protocol, String filePath) {
        if (!ObserveUtils.isObservabilityEnabled()) {
            return null;
        }
        try {
            SmbObserverContext ctx = new SmbObserverContext(
                    SmbMetricsUtil.CONTEXT_LISTENER, url, protocol);
            ctx.addTag(SmbObserverContext.TAG_ACTION_TYPE, SmbMetricsUtil.ACTION_TYPE_EVENT);
            String instanceUrl = SmbMetricsUtil.getInstanceUrl();
            if (instanceUrl != null) {
                ctx.addTag(SmbObserverContext.TAG_INSTANCE_URL, instanceUrl);
            }
            BSpan span = BSpan.start("smb", "file-lifecycle", false);
            if (filePath != null) {
                span.addTag(SmbObserverContext.TAG_FILE_PATH, filePath);
            }
            ctx.setSpan(span);
            return ctx;
        } catch (Throwable t) {
            log.debug("Failed to create file lifecycle context", t);
            return null;
        }
    }

    /**
     * Sets a parent context on the observer context inside strand properties, so that the
     * auto-instrumented span created by {@code callMethod} becomes a child of the parent's span.
     *
     * @param strandProperties the strand properties map (may be null)
     * @param parentCtx        the parent context with a span set on it (may be null)
     */
    public static void setParentContext(Map<String, Object> strandProperties,
                                         SmbObserverContext parentCtx) {
        if (strandProperties == null || parentCtx == null) {
            return;
        }
        try {
            Object ctxObj = strandProperties.get(ObservabilityConstants.KEY_OBSERVER_CONTEXT);
            if (ctxObj instanceof ObserverContext ctx) {
                ctx.setParent(parentCtx);
            }
        } catch (Throwable t) {
            log.debug("Failed to set parent context on strand properties", t);
        }
    }

    /**
     * Finishes the per-file parent span. Must be called exactly once per file, after all
     * processing (handler + cleanup) has completed.
     *
     * @param parentCtx the parent context returned by {@link #createFileLifecycleContext}, or null
     */
    public static void finishFileLifecycleSpan(SmbObserverContext parentCtx) {
        if (parentCtx == null) {
            return;
        }
        try {
            BSpan span = parentCtx.getSpan();
            if (span != null) {
                span.finishSpan();
            }
        } catch (Throwable t) {
            log.debug("Failed to finish file lifecycle span", t);
        }
    }

    /**
     * Creates strand properties containing an {@link SmbObserverContext} for a listener event dispatch.
     *
     * @param context   {@link SmbMetricsUtil#CONTEXT_LISTENER}
     * @param url       host:port of the remote server
     * @param protocol  the wire protocol
     * @param eventType event type tag value
     * @param filePath  retained for API compatibility; not added to metric labels
     * @return properties map, or {@code null} if observability is disabled
     */
    public static Map<String, Object> createStrandProperties(String context, String url, String protocol,
                                                              String eventType, String filePath) {
        if (!ObserveUtils.isObservabilityEnabled()) {
            return null;
        }
        try {
            SmbObserverContext observerContext = new SmbObserverContext(context, url, protocol);
            observerContext.addTag(SmbObserverContext.TAG_ACTION_TYPE, SmbMetricsUtil.ACTION_TYPE_EVENT);
            String instanceUrl = SmbMetricsUtil.getInstanceUrl();
            if (instanceUrl != null) {
                observerContext.addTag(SmbObserverContext.TAG_INSTANCE_URL, instanceUrl);
            }
            observerContext.addTag(SmbObserverContext.TAG_EVENT_TYPE, eventType);
            Map<String, Object> properties = new HashMap<>();
            properties.put(ObservabilityConstants.KEY_OBSERVER_CONTEXT, observerContext);
            return properties;
        } catch (Throwable t) {
            log.debug("Failed to create strand properties", t);
            return null;
        }
    }

    /**
     * Overload without {@code filePath} for dispatches that have no single source file.
     */
    public static Map<String, Object> createStrandProperties(String context, String url, String protocol,
                                                              String eventType) {
        return createStrandProperties(context, url, protocol, eventType, null);
    }

    /**
     * Creates strand properties for a listener file lifecycle event with file stage, handler name,
     * and file metadata.
     *
     * @param context      context tag
     * @param url          host:port
     * @param protocol     protocol string
     * @param eventType    event type
     * @param fileStage    file lifecycle stage
     * @param handlerName  handler method name, or {@code null}
     * @param fileSize     file size in bytes, or -1 if unknown
     * @param modifiedTime last-modified timestamp, or -1 if unknown
     * @return properties map, or {@code null} if observability is disabled
     */
    public static Map<String, Object> createFileStageStrandProperties(String context, String url, String protocol,
                                                                       String eventType, String fileStage,
                                                                       String handlerName, long fileSize,
                                                                       long modifiedTime) {
        if (!ObserveUtils.isObservabilityEnabled()) {
            return null;
        }
        try {
            SmbObserverContext observerContext = new SmbObserverContext(context, url, protocol);
            observerContext.addTag(SmbObserverContext.TAG_ACTION_TYPE, SmbMetricsUtil.ACTION_TYPE_EVENT);
            String instanceUrl = SmbMetricsUtil.getInstanceUrl();
            if (instanceUrl != null) {
                observerContext.addTag(SmbObserverContext.TAG_INSTANCE_URL, instanceUrl);
            }
            observerContext.addTag(SmbObserverContext.TAG_EVENT_TYPE, eventType);
            observerContext.addTag(SmbObserverContext.TAG_FILE_STAGE, fileStage);
            if (handlerName != null) {
                observerContext.addTag(SmbObserverContext.TAG_HANDLER_NAME, handlerName);
            }
            if (fileSize >= 0) {
                observerContext.addProperty(SmbObserverContext.TAG_FILE_SIZE, fileSize);
            }
            if (modifiedTime >= 0) {
                observerContext.addProperty(SmbObserverContext.TAG_FILE_MODIFIED_TIME, modifiedTime);
            }
            Map<String, Object> properties = new HashMap<>();
            properties.put(ObservabilityConstants.KEY_OBSERVER_CONTEXT, observerContext);
            return properties;
        } catch (Throwable t) {
            log.debug("Failed to create file stage strand properties", t);
            return null;
        }
    }

    /**
     * Creates strand properties for a cleanup (post-processing) span.
     *
     * @param context       context tag
     * @param url           host:port
     * @param protocol      protocol string
     * @param cleanupAction cleanup action type (move, delete)
     * @param handlerName   handler method name that triggered this cleanup
     * @return properties map, or {@code null} if observability is disabled
     */
    public static Map<String, Object> createCleanupStrandProperties(String context, String url, String protocol,
                                                                     String cleanupAction, String handlerName) {
        if (!ObserveUtils.isObservabilityEnabled()) {
            return null;
        }
        try {
            SmbObserverContext observerContext = new SmbObserverContext(context, url, protocol);
            observerContext.addTag(SmbObserverContext.TAG_ACTION_TYPE, SmbMetricsUtil.ACTION_TYPE_EVENT);
            String instanceUrl = SmbMetricsUtil.getInstanceUrl();
            if (instanceUrl != null) {
                observerContext.addTag(SmbObserverContext.TAG_INSTANCE_URL, instanceUrl);
            }
            observerContext.addTag(SmbObserverContext.TAG_FILE_STAGE, SmbMetricsUtil.FILE_STAGE_CLEANED_UP);
            observerContext.addTag(SmbObserverContext.TAG_CLEANUP_ACTION, cleanupAction);
            if (handlerName != null) {
                observerContext.addTag(SmbObserverContext.TAG_HANDLER_NAME, handlerName);
            }
            Map<String, Object> properties = new HashMap<>();
            properties.put(ObservabilityConstants.KEY_OBSERVER_CONTEXT, observerContext);
            return properties;
        } catch (Throwable t) {
            log.debug("Failed to create cleanup strand properties", t);
            return null;
        }
    }

    /**
     * Creates strand properties for a listener error dispatch.
     *
     * @param context   context tag
     * @param url       host:port
     * @param protocol  protocol string
     * @param filePath  path of the file involved, or {@code null}
     * @param errorType Ballerina error type name
     * @return properties map, or {@code null} if observability is disabled
     */
    public static Map<String, Object> createErrorStrandProperties(String context, String url, String protocol,
                                                                   String filePath, String errorType) {
        try {
            Map<String, Object> props = createStrandProperties(context, url, protocol,
                    SmbMetricsUtil.EVENT_TYPE_ERROR, filePath);
            if (props != null) {
                SmbObserverContext ctx = (SmbObserverContext) props.get(
                        ObservabilityConstants.KEY_OBSERVER_CONTEXT);
                ctx.addTag(SmbObserverContext.TAG_ERROR_TYPE, errorType);
                ctx.addTag(SmbObserverContext.TAG_OUTCOME, SmbMetricsUtil.OUTCOME_FAILURE);
            }
            return props;
        } catch (Throwable t) {
            log.debug("Failed to create error strand properties", t);
            return null;
        }
    }

    /**
     * Adds outcome and optional error type tags to strand properties.
     *
     * @param strandProperties the strand properties map (may be null)
     * @param outcome          success or failure
     * @param errorType        error type, or null
     */
    public static void addOutcomeToStrandProperties(Map<String, Object> strandProperties, String outcome,
                                                     String errorType) {
        if (strandProperties == null) {
            return;
        }
        try {
            SmbObserverContext ctx = (SmbObserverContext) strandProperties.get(
                    ObservabilityConstants.KEY_OBSERVER_CONTEXT);
            if (ctx == null) {
                return;
            }
            ctx.addTag(SmbObserverContext.TAG_OUTCOME, outcome);
            if (errorType != null) {
                ctx.addTag(SmbObserverContext.TAG_ERROR_TYPE, errorType);
            }
        } catch (Throwable t) {
            log.debug("Failed to add outcome to strand properties", t);
        }
    }

    /**
     * Enriches the auto-instrumented span for the currently executing native external method with
     * SMB client-operation tags.
     *
     * @param env           the current Ballerina environment
     * @param url           remote URL
     * @param protocol      protocol string
     * @param operationType one of the {@code SmbMetricsUtil.OPERATION_TYPE_*} constants
     * @param filePath      source/target file path
     */
    public static void sendMetricsData(Environment env, String url, String protocol,
                                       String operationType, String filePath) {
        sendMetricsData(env, url, protocol, operationType, filePath, null);
    }

    /**
     * Variant for two-path operations ({@code rename}, {@code move}, {@code copy}), adding
     * a span-only {@code destination.path} tag.
     *
     * @param env             the current Ballerina environment
     * @param url             remote URL
     * @param protocol        protocol string
     * @param operationType   operation type constant
     * @param filePath        source path
     * @param destinationPath destination path, or {@code null}
     */
    public static void sendMetricsData(Environment env, String url, String protocol,
                                       String operationType, String filePath,
                                       String destinationPath) {
        try {
            ObserverContext ctx = ObserveUtils.getObserverContextOfCurrentFrame(env);
            if (ctx == null) {
                return;
            }
            ctx.addTag(SmbObserverContext.TAG_MODULE, SmbMetricsUtil.MODULE_SMB);
            ctx.addTag(SmbObserverContext.TAG_ACTION_TYPE, SmbMetricsUtil.ACTION_TYPE_OPERATION);
            ctx.addTag(SmbObserverContext.TAG_CONTEXT, SmbMetricsUtil.CONTEXT_CLIENT);
            ctx.addTag(SmbObserverContext.TAG_REMOTE_URL, url);
            ctx.addTag(SmbObserverContext.TAG_PROTOCOL, protocol);
            ctx.addTag(SmbObserverContext.TAG_OPERATION_TYPE, operationType);
            String instanceUrl = SmbMetricsUtil.getInstanceUrl();
            if (instanceUrl != null) {
                ctx.addTag(SmbObserverContext.TAG_INSTANCE_URL, instanceUrl);
            }
            BSpan span = ctx.getSpan();
            if (span != null) {
                span.addTag(SmbObserverContext.TAG_FILE_PATH, filePath);
                if (destinationPath != null) {
                    span.addTag(SmbObserverContext.TAG_DESTINATION_PATH, destinationPath);
                }
            }
        } catch (Throwable t) {
            log.debug("Failed to send metrics data", t);
        }
    }

    /**
     * Tags the auto-instrumented span of the current frame as a poll cycle span.
     *
     * @param env      the current Ballerina environment
     * @param url      remote URL
     * @param protocol protocol string
     */
    public static void sendPollMetricsData(Environment env, String url, String protocol) {
        try {
            ObserverContext ctx = ObserveUtils.getObserverContextOfCurrentFrame(env);
            if (ctx == null) {
                return;
            }
            ctx.addTag(SmbObserverContext.TAG_MODULE, SmbMetricsUtil.MODULE_SMB);
            ctx.addTag(SmbObserverContext.TAG_ACTION_TYPE, SmbMetricsUtil.ACTION_TYPE_POLL);
            ctx.addTag(SmbObserverContext.TAG_CONTEXT, SmbMetricsUtil.CONTEXT_LISTENER);
            ctx.addTag(SmbObserverContext.TAG_REMOTE_URL, url != null ? url : SmbMetricsUtil.UNKNOWN);
            ctx.addTag(SmbObserverContext.TAG_PROTOCOL, protocol != null ? protocol : SmbMetricsUtil.UNKNOWN);
            String instanceUrl = SmbMetricsUtil.getInstanceUrl();
            if (instanceUrl != null) {
                ctx.addTag(SmbObserverContext.TAG_INSTANCE_URL, instanceUrl);
            }
        } catch (Throwable t) {
            log.debug("Failed to send poll metrics data", t);
        }
    }

    /**
     * Adds the outcome tag to the poll span on the current frame.
     *
     * @param env     the current Ballerina environment
     * @param outcome success or failure
     */
    public static void sendPollOutcome(Environment env, String outcome) {
        try {
            ObserverContext ctx = ObserveUtils.getObserverContextOfCurrentFrame(env);
            if (ctx == null) {
                return;
            }
            ctx.addTag(SmbObserverContext.TAG_OUTCOME, outcome);
        } catch (Throwable t) {
            log.debug("Failed to send poll outcome", t);
        }
    }

    /**
     * Adds {@code error=true} and {@code error.type} tags to the auto-instrumented span for the
     * currently executing native external method.
     *
     * @param env       the current Ballerina environment
     * @param errorType Ballerina error type name
     */
    public static void sendErrorMetricsOnCurrentFrame(Environment env, String errorType) {
        try {
            ObserverContext ctx = ObserveUtils.getObserverContextOfCurrentFrame(env);
            if (ctx == null) {
                return;
            }
            ctx.addTag(ObservabilityConstants.TAG_KEY_ERROR, ObservabilityConstants.TAG_TRUE_VALUE);
            ctx.addTag(SmbObserverContext.TAG_ERROR_TYPE, errorType);
            ctx.addTag(SmbObserverContext.TAG_OUTCOME, SmbMetricsUtil.OUTCOME_FAILURE);
        } catch (Throwable t) {
            log.debug("Failed to send error metrics on current frame", t);
        }
    }

    /**
     * Adds file metadata as span-only properties to strand properties.
     *
     * @param strandProperties the strand properties map (may be null)
     * @param fileSize         file size in bytes, or -1 if unknown
     * @param modifiedTime     last-modified timestamp, or -1 if unknown
     * @param filePath         file path for span-only tag
     */
    public static void addFileMetadataToStrandProperties(Map<String, Object> strandProperties,
                                                          long fileSize, long modifiedTime, String filePath) {
        if (strandProperties == null) {
            return;
        }
        try {
            SmbObserverContext ctx = (SmbObserverContext) strandProperties.get(
                    ObservabilityConstants.KEY_OBSERVER_CONTEXT);
            if (ctx == null) {
                return;
            }
            if (fileSize >= 0) {
                ctx.addProperty(SmbObserverContext.TAG_FILE_SIZE, fileSize);
            }
            if (modifiedTime >= 0) {
                ctx.addProperty(SmbObserverContext.TAG_FILE_MODIFIED_TIME, modifiedTime);
            }
            if (filePath != null) {
                ctx.addProperty(SmbObserverContext.TAG_FILE_PATH, filePath);
            }
        } catch (Throwable t) {
            log.debug("Failed to add file metadata to strand properties", t);
        }
    }
}
