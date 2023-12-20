/**
 * @name Load 3rd party classes or code ('unsafe reflection') without signature check
 * @description Load classes or code from 3rd party package without checking the
 *              package signature but only rely on package name.
 *              This makes it susceptible to package namespace squatting
 *              potentially leading to arbitrary code execution.
 * @problem.severity error
 * @precision high
 * @kind path-problem
 * @id java/unsafe-reflection
 * @tags security
 *       experimental
 *       external/cwe/cwe-470
 */

import java
import semmle.code.java.dataflow.DataFlow
import semmle.code.java.dataflow.TaintTracking
import semmle.code.java.controlflow.Guards
import semmle.code.java.dataflow.SSA
import semmle.code.java.frameworks.android.Intent

class CheckSignaturesGuard extends Guard instanceof EqualityTest {
  MethodAccess checkSignatures;

  CheckSignaturesGuard() {
    this.getAnOperand() = checkSignatures and
    checkSignatures
        .getMethod()
        .hasQualifiedName("android.content.pm", "PackageManager", "checkSignatures") and
    exists(Expr signatureCheckResult |
      this.getAnOperand() = signatureCheckResult and signatureCheckResult != checkSignatures
    |
      signatureCheckResult.(CompileTimeConstantExpr).getIntValue() = 0 or
      signatureCheckResult
          .(FieldRead)
          .getField()
          .hasQualifiedName("android.content.pm", "PackageManager", "SIGNATURE_MATCH")
    )
  }

  Expr getCheckedExpr() { result = checkSignatures.getArgument(0) }
}

predicate signatureChecked(Expr safe) {
  exists(CheckSignaturesGuard g, SsaVariable v |
    v.getAUse() = g.getCheckedExpr() and
    safe = v.getAUse() and
    g.controls(safe.getBasicBlock(), g.(EqualityTest).polarity())
  )
}

module InsecureLoadingConfig implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node src) {
    exists(Method m | m = src.asExpr().(MethodAccess).getMethod() |
      m.getDeclaringType().getASourceSupertype*() instanceof TypeContext and
      m.hasName("createPackageContext") and
      not signatureChecked(src.asExpr().(MethodAccess).getArgument(0))
    )
  }

  predicate isSink(DataFlow::Node sink) {
    exists(MethodAccess ma |
      ma.getMethod().hasQualifiedName("java.lang", "ClassLoader", "loadClass")
    |
      sink.asExpr() = ma.getQualifier()
    )
  }

  predicate isAdditionalFlowStep(DataFlow::Node node1, DataFlow::Node node2) {
    exists(MethodAccess ma, Method m |
      ma.getMethod() = m and
      m.getDeclaringType().getASourceSupertype*() instanceof TypeContext and
      m.hasName("getClassLoader")
    |
      node1.asExpr() = ma.getQualifier() and
      node2.asExpr() = ma
    )
  }
}

module InsecureLoadFlow = TaintTracking::Global<InsecureLoadingConfig>;

import InsecureLoadFlow::PathGraph

from InsecureLoadFlow::PathNode source, InsecureLoadFlow::PathNode sink
where InsecureLoadFlow::flowPath(source, sink)
select sink.getNode(), source, sink, "Class loaded from a $@ without signature check",
  source.getNode(), "third party library"

