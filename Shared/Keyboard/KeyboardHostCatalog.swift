import Foundation

enum KeyboardHostCatalog {
    static func destination(host: String) -> URL? {
        (customSchemes[host] ?? universalLinks[host]).flatMap(URL.init(string:))
    }

    private static let customSchemes = [
        "com.t3tools.t3code": "t3code://",
        "com.apple.mobilenotes": "mobilenotes://",
        "com.apple.MobileSMS": "ichat://",
        "com.apple.mobilemail": "message://",
        "com.apple.reminders": "x-apple-reminderkit://",
        "net.whatsapp.WhatsApp": "whatsapp-consumer://",
        "net.whatsapp.WhatsAppSMB": "whatsapp://",
        "com.telegram.telegram-ios": "tg://",
        "ph.telegra.Telegraph": "tg://",
        "app.swiftgram.ios": "sg://",
        "app.nicegram": "nicegram://",
        "org.whispersystems.signal": "sgnl://",
        "com.facebook.Messenger": "fb-messenger://",
        "com.hammerandchisel.discord": "discord://",
        "com.microsoft.skype.teams": "msteams://",
        "com.tinyspeck.chatlyio": "slack://open",
        "com.viber": "viber://",
        "jp.naver.line": "line://",
        "com.tencent.xin": "weixin://",
        "ch.threema.iapp": "threema://",
        "com.mattermost.rn": "mattermost://",
        "io.element.elementx": "io.element.elementx://",
        "com.iwilab.KakaoTalk": "kakaotalk://",
        "com.automattic.beeper": "beeper://",
        "com.facebook.Facebook": "fb://",
        "com.burbn.instagram": "instagram://",
        "com.toyopagroup.picaboo": "snapchat://",
        "com.burbn.barcelona": "barcelona://",
        "com.atebits.Tweetie2": "twitter://",
        "com.reddit.Reddit": "reddit://",
        "com.linkedin.LinkedIn": "linkedin://",
        "com.google.Gmail": "googlegmail://",
        "com.microsoft.Office.Outlook": "ms-outlook://",
        "com.readdle.smartemail": "readdle-spark://",
        "com.openai.chat": "com.openai.chat://",
        "com.anthropic.claude": "claude://",
        "com.google.gemini": "gemini-app://",
        "ai.perplexity.app": "perplexity-app://",
        "ai.x.GrokApp": "grok://",
        "im.monica.app.monica": "monica://"
    ]

    private static let universalLinks = [
        "com.google.Dynamite": "https://chat.google.com/",
        "com.facebook.stellaapp": "https://www.meta.ai/",
        "com.moonshot.kimichat": "https://kimi.com/app/",
        "com.tongyi.intl": "https://qwen.com/app/",
        "com.google.NotebookLM": "https://notebooklm.google/app",
        "com.microsoft.officemobile": "https://m365.cloud.microsoft/"
    ]
}
