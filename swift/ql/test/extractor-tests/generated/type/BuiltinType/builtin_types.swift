//codeql-extractor-options: -parse-stdlib
func foo(
  _: Builtin.IntLiteral,
  _: Builtin.FPIEEE32,
  _: Builtin.FPIEEE64,
  _: Builtin.BridgeObject,
  _: Builtin.DefaultActorStorage,
  _: Builtin.Executor,
  _: Builtin.Job,
  _: Builtin.NativeObject,
  _: Builtin.RawPointer,
  _: Builtin.RawUnsafeContinuation,
  _: Builtin.UnsafeValueBuffer
) {}
