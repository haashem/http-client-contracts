class LoginRefreshOutcome {
  const LoginRefreshOutcome({
    required this.message,
    required this.accessToken,
    required this.workoutCount,
  });

  final String message;
  final String? accessToken;
  final int workoutCount;
}
