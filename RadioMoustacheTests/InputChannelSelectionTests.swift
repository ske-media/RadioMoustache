import Foundation
import Testing
@testable import RadioMoustache

struct InputChannelSelectionTests {
    @Test func monoDeviceOffersASingleChannel() {
        #expect(InputChannelSelection.options(forChannelCount: 1) == [.mono(0)])
    }

    @Test func twoChannelInterfaceOffersEachInputAndTheStereoPair() {
        #expect(InputChannelSelection.options(forChannelCount: 2) == [.mono(0), .mono(1), .stereo(first: 0)])
    }

    @Test func fourChannelInterfaceOffersTwoStereoPairs() {
        #expect(
            InputChannelSelection.options(forChannelCount: 4)
                == [.mono(0), .mono(1), .mono(2), .mono(3), .stereo(first: 0), .stereo(first: 2)]
        )
    }

    @Test func oddChannelCountNeverOffersAnIncompletePair() {
        #expect(!InputChannelSelection.options(forChannelCount: 3).contains(.stereo(first: 2)))
    }

    @Test func validityDependsOnTheDeviceChannelCount() {
        #expect(InputChannelSelection.mono(1).isValid(forChannelCount: 2))
        #expect(!InputChannelSelection.mono(2).isValid(forChannelCount: 2))
        #expect(InputChannelSelection.stereo(first: 0).isValid(forChannelCount: 2))
        #expect(!InputChannelSelection.stereo(first: 1).isValid(forChannelCount: 2))
    }

    @Test func survivesAJSONRoundTrip() throws {
        for selection in [InputChannelSelection.mono(3), .stereo(first: 2)] {
            let data = try JSONEncoder().encode(selection)
            #expect(try JSONDecoder().decode(InputChannelSelection.self, from: data) == selection)
        }
    }

    @Test func labelsUseHumanNumbering() {
        #expect(InputChannelSelection.mono(0).label(on: nil).contains("1"))
        #expect(InputChannelSelection.stereo(first: 2).label(on: nil).contains("3-4"))
    }
}
