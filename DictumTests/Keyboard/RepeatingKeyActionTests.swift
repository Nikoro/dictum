@testable import Dictum
import Testing

@MainActor
struct RepeatingKeyActionTests {
    @Test func `holding delete repeats until release and release stops pending deletes`() async {
        var deletions = 0
        let key = RepeatingKeyAction(wait: { _ in await Task.yield() }, action: { deletions += 1 })
        key.press()
        #expect(deletions == 1)
        for _ in 0 ..< 100 where deletions < 3 {
            await Task.yield()
        }
        #expect(deletions >= 3)
        key.release()
        let releasedCount = deletions
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        #expect(deletions == releasedCount)
    }

    @Test func `a quick tap deletes once and a new press cannot revive the previous repeat`() async {
        var deletions = 0
        let key = RepeatingKeyAction(wait: { _ in await Task.yield() }, action: { deletions += 1 })
        key.press()
        key.release()
        key.press()
        key.release()
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        #expect(deletions == 2)
    }
}
