import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server Error']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Cache Error']);
}

class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Permission Denied']);
}

class DetectionFailure extends Failure {
  const DetectionFailure([super.message = 'Detection Error']);
}
