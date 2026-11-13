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

private actor RepeatDelays {
    private(set) var values: [Duration] = []

    func record(_ delay: Duration) throws {
        values.append(delay)
        if values.count >= 30 {
            throw CancellationError()
        }
    }
}

extension RepeatingKeyActionTests {
    @Test func `a sustained hold transitions from character repeats to word cadence`() async {
        let delays = RepeatDelays()
        let key = RepeatingKeyAction(wait: { try await delays.record($0) }, action: {})
        key.press()
        for _ in 0 ..< 5000 {
            if await delays.values.count >= 30 {
                break
            }
            await Task.yield()
        }
        key.release()
        let values = await delays.values
        #expect(values.first == .milliseconds(500))
        #expect(values.contains(.milliseconds(200)))
    }

    @Test func `word repeats stop on release and the next press starts with a character`() async {
        let delays = RepeatDelays()
        var characters = 0
        var words = 0
        let key = RepeatingKeyAction(
            accelerationAfter: 2,
            wait: { try await delays.record($0) },
            acceleratedAction: { words += 1 },
            action: { characters += 1 }
        )
        key.press()
        for _ in 0 ..< 5000 {
            if await delays.values.count >= 30 {
                break
            }
            await Task.yield()
        }
        key.release()
        #expect(characters == 3)
        #expect(words > 0)
        let releasedWords = words
        key.press()
        key.release()
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        #expect(characters == 4)
        #expect(words == releasedWords)
    }
}
