import Foundation

struct HealthData: Codable {
  let stepCount: Double?
  let heartRate: Double?
  let activeEnergyBurned: Double?
  let distanceWalkingRunning: Double?
  let bodyMass: Double?
  let height: Double?
  let mindfulMinutes: Double?
  let sleepSegments: [SleepSegment]?
  let totalSleepMinutes: Int?
  let timestamp: Date
  let isIncremental: Bool // 증분 데이터 여부
  let sinceDateString: String? // 마지막 동기화 시간 (증분 데이터인 경우)

  init(
    stepCount: Double?,
    heartRate: Double?,
    activeEnergyBurned: Double?,
    distanceWalkingRunning: Double?,
    bodyMass: Double?,
    height: Double?,
    mindfulMinutes: Double?,
    sleepSegments: [SleepSegment]?,
    totalSleepMinutes: Int?,
    timestamp: Date,
    isIncremental: Bool = false,
    sinceDate: Date? = nil
  ) {
      self.stepCount = stepCount
      self.heartRate = heartRate
      self.activeEnergyBurned = activeEnergyBurned
      self.distanceWalkingRunning = distanceWalkingRunning
      self.bodyMass = bodyMass
      self.height = height
      self.mindfulMinutes = mindfulMinutes
      self.sleepSegments = sleepSegments
      self.totalSleepMinutes = totalSleepMinutes
      self.timestamp = timestamp
      self.isIncremental = isIncremental
      self.sinceDateString = sinceDate.map { ISO8601DateFormatter().string(from: $0) }
    }

    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "isIncremental": isIncremental
        ]

        if let sinceDateString = sinceDateString {
            dict["sinceDate"] = sinceDateString
        }

        if let stepCount = stepCount {
            dict["stepCount"] = stepCount
        }
        if let heartRate = heartRate {
            dict["heartRate"] = heartRate
        }
        if let activeEnergyBurned = activeEnergyBurned {
            dict["activeEnergyBurned"] = activeEnergyBurned
        }
        if let distanceWalkingRunning = distanceWalkingRunning {
            dict["distanceWalkingRunning"] = distanceWalkingRunning
        }
        if let bodyMass = bodyMass {
            dict["bodyMass"] = bodyMass
        }
        if let height = height {
            dict["height"] = height
        }
        if let mindfulMinutes = mindfulMinutes {
            dict["mindfulMinutes"] = mindfulMinutes
        }

        return dict
    }
}
