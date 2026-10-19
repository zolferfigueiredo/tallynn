import Testing
@testable import Tallynn

@Test func everyLanguageHasEnglishKeysAndPlaceholders() {
    let placeholders = { (text: String) in Set(text.matches(of: /\{\w+\}/).map { String($0.output) }) }
    for (language, table) in Strings.all {
        #expect(Set(table.keys) == Set(Strings.en.keys), "\(language.rawValue)")
        for (key, text) in Strings.en {
            #expect(placeholders(table[key] ?? "") == placeholders(text), "\(language.rawValue) \(key)")
        }
    }
}

@Test func fillsPlaceholdersAndFallsBackToTheKey() {
    #expect(tr("signed_in_as", ["login": "zolfer"], in: .en) == "Signed in as @zolfer")
    #expect(tr("minutes", ["n": 5], in: .pl) == "5 minut")
    #expect(tr("hour", in: .ja) == "1 時間")
    #expect(tr("no-such-key", in: .de) == "no-such-key")
}
