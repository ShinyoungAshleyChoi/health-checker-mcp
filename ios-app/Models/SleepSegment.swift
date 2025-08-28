import Foundation

struct SleepSegment: Codable, Equatable {
    enum State: String, Codable {
        case inBed, asleep, awake
    }
    
    let startDate: Date
    let endDate: Date
    let state: State
}
