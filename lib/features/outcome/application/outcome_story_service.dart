import '../../play_loop/domain/run_summary.dart';
import '../domain/outcome_story_content.dart';

/// Content source for the outcome card (architecture v4 §2) — local today,
/// remote later, zero UI/flow churn either way. Never throws: a failed fetch
/// (real or simulated) resolves to `OutcomeStoryContent.naFor` rather than
/// an exception, so the UI never needs an error state or a retry.
abstract class OutcomeStoryService {
  Future<OutcomeStoryContent> fetchStory(RunSummary summary);
}
