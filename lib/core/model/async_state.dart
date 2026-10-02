import 'package:flutter/foundation.dart';

/// 页面级状态：Idle / Loading / Data / Error。
/// 对应 Android 每个 Screen 里手写的 isLoading + errorMessage + data 三件套。
@immutable
sealed class AsyncState<T> {
  const AsyncState();

  const factory AsyncState.idle() = AsyncIdle<T>;

  const factory AsyncState.loading() = AsyncLoading<T>;

  const factory AsyncState.data(T value) = AsyncData<T>;

  const factory AsyncState.error(Object error, [StackTrace? stackTrace]) =
      AsyncError<T>;

  bool get isLoading => this is AsyncLoading<T>;

  bool get hasData => this is AsyncData<T>;

  T? get valueOrNull => switch (this) {
    AsyncData<T>(:final value) => value,
    _ => null,
  };

  Object? get errorOrNull => switch (this) {
    AsyncError<T>(:final error) => error,
    _ => null,
  };
}

final class AsyncIdle<T> extends AsyncState<T> {
  const AsyncIdle();
}

final class AsyncLoading<T> extends AsyncState<T> {
  const AsyncLoading();
}

final class AsyncData<T> extends AsyncState<T> {
  const AsyncData(this.value);

  final T value;
}

final class AsyncError<T> extends AsyncState<T> {
  const AsyncError(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;
}
