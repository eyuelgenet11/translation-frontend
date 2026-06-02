/// Normalizes job status strings from Supabase (mixed casing).
String normalizeJobStatus(dynamic status) {
  return (status?.toString() ?? '').trim().toLowerCase().replaceAll('_', ' ');
}

bool jobStatusIs(dynamic status, String expected) {
  return normalizeJobStatus(status) == normalizeJobStatus(expected);
}

bool jobStatusIn(dynamic status, List<String> expected) {
  final n = normalizeJobStatus(status);
  return expected.map(normalizeJobStatus).contains(n);
}
