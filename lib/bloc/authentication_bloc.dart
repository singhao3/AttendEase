import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

part 'authentication_event.dart';
part 'authentication_state.dart';

class AuthenticationBloc
    extends Bloc<AuthenticationEvent, AuthenticationState> {
  AuthenticationBloc() : super(AuthenticationInitial());

  @override
  // ignore: override_on_non_overriding_member
  Stream<AuthenticationState> mapEventToState(
    AuthenticationEvent event,
  ) async* {
    if (event is AppStarted) {
      yield* _mapAppStartedToState();
    } else if (event is UserLoggedIn) {
      yield* _mapUserLoggedInToState();
    } else if (event is UserLoggedOut) {
      yield* _mapUserLoggedOutToState();
    }
  }

  Stream<AuthenticationState> _mapAppStartedToState() async* {
    // Check if the user is authenticated or not
    // You can use Firebase Auth or any other authentication method here
    // For now, let's assume the user is authenticated
    yield AuthenticationAuthenticated();
  }

  Stream<AuthenticationState> _mapUserLoggedInToState() async* {
    yield AuthenticationAuthenticated();
  }

  Stream<AuthenticationState> _mapUserLoggedOutToState() async* {
    yield AuthenticationUnauthenticated();
  }
}
