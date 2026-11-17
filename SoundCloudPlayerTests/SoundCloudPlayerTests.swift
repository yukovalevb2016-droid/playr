import XCTest
@testable import SoundCloudPlayer

final class SoundCloudPlayerTests: XCTestCase {
    func testDurationFormatting() {
        XCTAssertEqual(TrackFormatting.duration(0), "0:00")
        XCTAssertEqual(TrackFormatting.duration(65_000), "1:05")
        XCTAssertEqual(TrackFormatting.duration(-1), "0:00")
    }

    func testPlayableTrackDecoding() throws {
        let json = #"{"id":"urn:sc:track:1","title":"Track","artist":"Artist","durationMilliseconds":125000,"artworkURL":null,"permalinkURL":"https://soundcloud.com/artist/track","playable":true}"#.data(using: .utf8)!
        let track = try JSONDecoder().decode(Track.self, from: json)
        XCTAssertTrue(track.playable)
        XCTAssertEqual(track.durationText, "2:05")
    }

    func testNonPlayableTrackDecoding() throws {
        let json = #"{"id":"urn:sc:track:2","title":"Restricted","artist":"Artist","durationMilliseconds":1000,"artworkURL":null,"permalinkURL":"https://soundcloud.com/artist/restricted","playable":false}"#.data(using: .utf8)!
        let track = try JSONDecoder().decode(Track.self, from: json)
        XCTAssertFalse(track.playable)
    }
}
