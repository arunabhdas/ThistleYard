import AVFoundation
import Foundation
import ImageIO
import OffsideGolfCore
import XCTest
@testable import OffsideGolf

func golfTestResource(_ name: String, extension ext: String) throws -> URL {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle.main
    #endif
    let folders: [String?] = [nil, "Courses", "Courses/Holes", "Textures", "Audio",
                              "Resources/Courses", "Resources/Courses/Holes", "Resources/Textures", "Resources/Audio"]
    return try XCTUnwrap(folders.compactMap { bundle.url(forResource: name, withExtension: ext, subdirectory: $0) }.first,
                         "Missing shipped resource: \(name).\(ext)")
}

@MainActor
final class CourseContentTests: XCTestCase {
    private func course() throws -> CourseManifest {
        try CourseManifest.decode(Data(contentsOf: golfTestResource("whispering-coast", extension: "json")))
    }
    private func hole(_ id: String) throws -> HoleDefinition {
        try HoleDefinition.decode(Data(contentsOf: golfTestResource(id, extension: "json")))
    }

    func testEveryManifestHoleLoadsWithMatchingIdentityParAndMeasuredRoute() throws {
        let course = try course()
        XCTAssertEqual(course.holes.count, 9)
        XCTAssertEqual(course.totalPar, 35)
        XCTAssertEqual(course.totalDistanceYards, 2_848)
        var actualPar = 0, actualYards = 0.0
        for summary in course.holes {
            let hole = try hole(summary.id)
            XCTAssertEqual(hole.id, summary.id)
            XCTAssertEqual(hole.par, summary.par)
            XCTAssertEqual(hole.contentVersion, course.contentVersion)
            let meters = zip(hole.route, hole.route.dropFirst()).reduce(0.0) { $0 + $1.0.distance(to: $1.1) }
            let yards = meters / 0.9144
            XCTAssertEqual(yards, Double(summary.distanceYards), accuracy: 0.1, hole.id)
            actualPar += hole.par; actualYards += yards
        }
        XCTAssertEqual(actualPar, 35)
        XCTAssertEqual(actualYards, 2_848, accuracy: 0.5)
    }

    func testTeesPinsSafeTargetsAndDropsArePlayableWithinAuthoredWindLimits() throws {
        let ranges: [ClosedRange<Double>] = [0...0, 1...2, 3...5, 1...3, 2...4, 3...5, 2...4, 3...6, 4...6]
        for summary in try course().holes {
            let hole = try hole(summary.id)
            XCTAssertTrue(ranges[summary.number - 1].contains(hole.wind.speedMPH), hole.id)
            XCTAssertTrue((0..<360).contains(hole.wind.towardDegrees), hole.id)
            XCTAssertEqual(hole.terrain(at: hole.tee), .tee, hole.id)
            XCTAssertEqual(hole.terrain(at: hole.pin), .green, hole.id)
            for point in [hole.tee, hole.pin, hole.safeTarget] + hole.drops.map(\.position) {
                XCTAssertTrue(hole.bounds.contains(point), hole.id)
                XCTAssertNotEqual(hole.terrain(at: point), .water, hole.id)
                XCTAssertNotEqual(hole.terrain(at: point), .outOfBounds, hole.id)
                XCTAssertFalse(hole.trees.contains { $0.position.distance(to: point) <= $0.trunkRadius + 0.5 }, hole.id)
            }
        }
    }

    func testLandmarksAndEveryDecorationResolveThroughArtLibrary() throws {
        let landmarks = ["windmill", "shed", "lookout", "arch", "farmhouse", "hide", "pavilion", "cabin", "lighthouse"]
        let art = ArtLibrary()
        for summary in try course().holes {
            let hole = try hole(summary.id)
            XCTAssertTrue(hole.decorations.contains { $0.asset == landmarks[summary.number - 1] }, hole.id)
            for decoration in hole.decorations {
                XCTAssertNotNil(art.environmentTexture(decoration.asset), "\(hole.id): unknown art \(decoration.asset)")
            }
        }
    }

    func testShippedTextureSheetsAndEveryAudioCueDecode() throws {
        for name in ["coast_environment_sheet", "terrain_sheet", "golfer_poses_sheet"] {
            let url = try golfTestResource(name, extension: "png")
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil), name)
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil), name)
            XCTAssertGreaterThan(image.width, 1); XCTAssertGreaterThan(image.height, 1)
        }
        let effects = GolfAudioEffect.allCases.map(\.resource)
        for (names, ext) in [(effects, "wav"), (["coast_music", "coast_birds", "coast_wind", "coast_waves"], "m4a")] {
            for name in names {
                let file = try AVAudioFile(forReading: golfTestResource(name, extension: ext))
                XCTAssertGreaterThan(file.length, 0, name)
                XCTAssertGreaterThan(file.processingFormat.sampleRate, 0, name)
                XCTAssertGreaterThan(file.processingFormat.channelCount, 0, name)
            }
        }
    }
}
