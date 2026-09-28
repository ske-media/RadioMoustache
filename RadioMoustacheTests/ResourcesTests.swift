import AppKit
import Testing
@testable import RadioMoustache

/// Les tests tournent dans l'app : on vérifie que ses polices et ses images sont bien embarquées.
@MainActor
struct ResourcesTests {
    @Test func bundledFontsAreUsable() {
        let failures = PirateFont.registerBundledFonts()

        #expect(failures.isEmpty)
        for name in PirateFont.bundledFonts {
            #expect(NSFont(name: name, size: 12) != nil, "Police introuvable : \(name)")
        }
    }

    @Test(arguments: DecorImage.allCases)
    func decorImagesAreInTheAssetCatalog(image: DecorImage) {
        #expect(NSImage(named: image.rawValue) != nil)
    }
}
