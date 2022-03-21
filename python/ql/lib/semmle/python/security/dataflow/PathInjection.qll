/**
 * Provides taint-tracking configurations for detecting "path injection" vulnerabilities.
 *
 * Note, for performance reasons: only import this file if
 * `PathInjection::Configuration` is needed, otherwise
 * `PathInjectionCustomizations` should be imported instead.
 */

private import python
private import semmle.python.Concepts
import semmle.python.dataflow.new.DataFlow
import semmle.python.dataflow.new.TaintTracking

/**
 * Provides a taint-tracking configuration for detecting "path injection" vulnerabilities.
 */
module PathInjection {
  import PathInjectionQuery // ignore-query-import
}


// ---------------------------------------------------------------------------
// Old, deprecated code
// ---------------------------------------------------------------------------
private import semmle.python.dataflow.new.DataFlow2
private import semmle.python.dataflow.new.TaintTracking2
private import ChainedConfigs12
import PathInjectionCustomizations::PathInjection

// ---------------------------------------------------------------------------
// Case 1. The path is never normalized.
// ---------------------------------------------------------------------------
/**
 * DEPRECATED: Use `PathInjection::Configuration` instead
 *
 * Configuration to find paths from sources to sinks that contain no normalization.
 */
deprecated class PathNotNormalizedConfiguration extends TaintTracking::Configuration {
  PathNotNormalizedConfiguration() { this = "PathNotNormalizedConfiguration" }

  override predicate isSource(DataFlow::Node source) { source instanceof Source }

  override predicate isSink(DataFlow::Node sink) { sink instanceof Sink }

  override predicate isSanitizer(DataFlow::Node node) {
    node instanceof Sanitizer
    or
    node instanceof Path::PathNormalization
  }

  override predicate isSanitizerGuard(DataFlow::BarrierGuard guard) {
    guard instanceof SanitizerGuard
  }
}

/**
 * DEPRECATED: Use `PathInjection::Configuration` instead
 *
 * Holds if there is a path injection from source to sink, where the (python) path is
 * not normalized.
 */
deprecated predicate pathNotNormalized(CustomPathNode source, CustomPathNode sink) {
  any(PathNotNormalizedConfiguration config).hasFlowPath(source.asNode1(), sink.asNode1())
}

// ---------------------------------------------------------------------------
// Case 2. The path is normalized at least once, but never checked afterwards.
// ---------------------------------------------------------------------------
/**
 * DEPRECATED: Use `PathInjection::Configuration` instead
 *
 * Configuration to find paths from sources to normalizations that contain no prior normalizations.
 */
deprecated class FirstNormalizationConfiguration extends TaintTracking::Configuration {
  FirstNormalizationConfiguration() { this = "FirstNormalizationConfiguration" }

  override predicate isSource(DataFlow::Node source) { source instanceof Source }

  override predicate isSink(DataFlow::Node sink) { sink instanceof Path::PathNormalization }

  override predicate isSanitizer(DataFlow::Node node) { node instanceof Sanitizer }

  override predicate isSanitizerOut(DataFlow::Node node) { node instanceof Path::PathNormalization }

  override predicate isSanitizerGuard(DataFlow::BarrierGuard guard) {
    guard instanceof SanitizerGuard
  }
}

/**
 * DEPRECATED: Use `PathInjection::Configuration` instead
 *
 * Configuration to find paths from normalizations to sinks that do not go through a check.
 */
deprecated class NormalizedPathNotCheckedConfiguration extends TaintTracking2::Configuration {
  NormalizedPathNotCheckedConfiguration() { this = "NormalizedPathNotCheckedConfiguration" }

  override predicate isSource(DataFlow::Node source) { source instanceof Path::PathNormalization }

  override predicate isSink(DataFlow::Node sink) { sink instanceof Sink }

  override predicate isSanitizer(DataFlow::Node node) { node instanceof Sanitizer }

  override predicate isSanitizerGuard(DataFlow::BarrierGuard guard) {
    guard instanceof Path::SafeAccessCheck
    or
    guard instanceof SanitizerGuard
  }
}

/**
 * DEPRECATED: Use `PathInjection::Configuration` instead
 *
 * Holds if there is a path injection from source to sink, where the (python) path is
 * normalized at least once, but never checked afterwards.
 */
deprecated predicate pathNotCheckedAfterNormalization(CustomPathNode source, CustomPathNode sink) {
  exists(
    FirstNormalizationConfiguration config, DataFlow::PathNode mid1, DataFlow2::PathNode mid2,
    NormalizedPathNotCheckedConfiguration config2
  |
    config.hasFlowPath(source.asNode1(), mid1) and
    config2.hasFlowPath(mid2, sink.asNode2()) and
    mid1.getNode().asCfgNode() = mid2.getNode().asCfgNode()
  )
}

// ---------------------------------------------------------------------------
// Query: Either case 1 or case 2.
// ---------------------------------------------------------------------------
/**
 * DEPRECATED: Use `PathInjection::Configuration` instead
 *
 * Holds if there is a path injection from source to sink
 */
deprecated predicate pathInjection(CustomPathNode source, CustomPathNode sink) {
  pathNotNormalized(source, sink)
  or
  pathNotCheckedAfterNormalization(source, sink)
}
