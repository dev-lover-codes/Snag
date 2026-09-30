/// Success/failure type returned by repository calls that the UI must handle.
sealed class Result<T> {
  const Result();
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.message, {this.retryable = true});
  final String message;
  final bool retryable;
}
