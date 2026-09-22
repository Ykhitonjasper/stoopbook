import Foundation

enum AppRoute: Hashable {
    case kit(VisitKitKind)
    case saveDraft(ReadingDraft)
    case readingDetail(String)
    case comparePair(String)
    case stopDetail(String)
    case exportPack(String)
    case roundBuilder(String)
}
