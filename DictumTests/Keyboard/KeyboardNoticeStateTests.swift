@testable import Dictum
import Testing

struct KeyboardNoticeStateTests {
    @Test func `closing an error keeps it hidden across repeated mailbox polls`() {
        var notice = KeyboardNoticeState()
        notice.update("Connection failed")
        #expect(notice.visibleMessage == "Connection failed")
        notice.dismiss()
        for _ in 0 ..< 10 {
            notice.update("Connection failed")
            #expect(notice.visibleMessage == nil)
        }
    }

    @Test func `retry hides the old error but a later failure is visible`() {
        var notice = KeyboardNoticeState()
        notice.update("Connection failed")
        notice.dismiss()
        notice.update("Connection failed")
        #expect(notice.visibleMessage == nil)
        notice.update(nil)
        notice.update("Connection failed")
        #expect(notice.visibleMessage == "Connection failed")
    }

    @Test func `a different error is shown after closing the previous one`() {
        var notice = KeyboardNoticeState()
        notice.update("Connection failed")
        notice.dismiss()
        notice.update("Enable full access")
        #expect(notice.visibleMessage == "Enable full access")
    }

    @Test func `legacy empty audio issues stay silent while genuine issues remain visible`() {
        #expect(KeyboardSession.Issue.noAudio.message == nil)
        #expect(KeyboardSession.Issue.noSpeech.message == nil)
        #expect(KeyboardSession.Issue.resultExpired.message?.isEmpty == false)
    }
}
