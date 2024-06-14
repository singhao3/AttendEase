import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meta/meta.dart';

part 'authentication_event.dart';
part 'authentication_state.dart';

class AuthenticationBloc extends Bloc<AuthenticationEvent, AuthenticationState> {
  AuthenticationBloc() : super(AuthenticationInitial()) {
    on<AppStarted>(_onAppStarted);
    on<UserLoggedIn>(_onUserLoggedIn);
    on<UserLoggedOut>(_onUserLoggedOut);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthenticationState> emit) async {
    emit(AuthenticationLoading());
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final role = await _fetchUserRole(user.uid);
      if (role == 'admin') {
        emit(AdminAuthenticated());
      } else {
        emit(AuthenticationAuthenticated());
      }
    } else {
      emit(AuthenticationUnauthenticated());
    }
  }

  Future<void> _onUserLoggedIn(UserLoggedIn event, Emitter<AuthenticationState> emit) async {
    final role = await _fetchUserRole(FirebaseAuth.instance.currentUser!.uid);
    if (role == 'admin') {
      emit(AdminAuthenticated());
    } else {
      emit(AuthenticationAuthenticated());
    }
  }

  Future<void> _onUserLoggedOut(UserLoggedOut event, Emitter<AuthenticationState> emit) async {
    await FirebaseAuth.instance.signOut();
    emit(AuthenticationUnauthenticated());
  }

  Future<String> _fetchUserRole(String uid) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return userDoc.data()?['role'] ?? 'user';
  }
}
