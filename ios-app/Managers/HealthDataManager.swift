import Foundation
import HealthKit
import SwiftUI

final class HealthDataManager: ObservableObject {
  private let healthStore = HKHealthStore()

  // Define the health data types we want to read
  private let healthDataTypes: Set<HKSampleType> = [
    HKQuantityType.quantityType(forIdentifier: .stepCount)!,
    HKQuantityType.quantityType(forIdentifier: .heartRate)!,
    HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
    HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
    HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
    HKQuantityType.quantityType(forIdentifier: .height)!,
    HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
    HKCategoryType.categoryType(forIdentifier: .mindfulSession)!
  ]

  func requestAuthorization() async throws {
    #if targetEnvironment(simulator)
    print("[HealthDataManager] 시뮬레이터에서 실행 중 - 권한 요청을 건너뜁니다.")
    return // 시뮬레이터에서는 권한 체크 없이 통과
    #else
    guard HKHealthStore.isHealthDataAvailable() else {
      throw HealthDataError.healthDataNotAvailable
    }

    return try await withCheckedThrowingContinuation { continuation in
      healthStore.requestAuthorization(toShare: [], read: healthDataTypes) { success, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if success {
          continuation.resume()
        } else {
          continuation.resume(throwing: HealthDataError.authorizationDenied)
        }
      }
    }
    #endif
  }

  func readHealthData() async throws -> HealthData {
    // 시뮬레이터에서는 모의 데이터 반환
    #if targetEnvironment(simulator)
    print("[HealthDataManager] 시뮬레이터에서 실행 중 - 모의 데이터를 사용합니다.")
    return generateMockHealthData()
    #else
    let calendar = Calendar.current
    let now = Date()
    let startOfDay = calendar.startOfDay(for: now)

    async let stepCount = readStepCount(from: startOfDay, to: now)
    async let heartRate = readLatestHeartRate()
    async let activeEnergy = readActiveEnergy(from: startOfDay, to: now)
    async let distance = readDistance(from: startOfDay, to: now)
    async let bodyMass = readLatestBodyMass()
    async let height = readLatestHeight()
    async let sleepSamples = readSleepAnalysis(from: startOfDay, to: now)
    async let mindfulMinutes = readMindfulMinutes(from: startOfDay, to: now)

    let samples = try await sleepSamples
    let (segments, total) = samples.map(mapSleepSamples) ?? ([], 0)

    return try await HealthData(
      stepCount: stepCount,
      heartRate: heartRate,
      activeEnergyBurned: activeEnergy,
      distanceWalkingRunning: distance,
      bodyMass: bodyMass,
      height: height,
      mindfulMinutes: mindfulMinutes,
      sleepSegments: segments.isEmpty ? nil : segments,
      totalSleepMinutes: segments.isEmpty ? nil : total,
      timestamp: now
    )
    #endif
  }

  private func readStepCount(from startDate: Date, to endDate: Date) async throws -> Double? {
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    return try await readQuantitySum(for: stepType, from: startDate, to: endDate, unit: .count())
  }

  private func readLatestHeartRate() async throws -> Double? {
    let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    return try await readLatestQuantity(for: heartRateType, unit: HKUnit.count().unitDivided(by: .minute()))
  }

  private func readActiveEnergy(from startDate: Date, to endDate: Date) async throws -> Double? {
    let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    return try await readQuantitySum(for: energyType, from: startDate, to: endDate, unit: .kilocalorie())
  }

  private func readDistance(from startDate: Date, to endDate: Date) async throws -> Double? {
    let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
    return try await readQuantitySum(for: distanceType, from: startDate, to: endDate, unit: .meter())
  }

  private func readLatestBodyMass() async throws -> Double? {
    let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
    return try await readLatestQuantity(for: bodyMassType, unit: .gramUnit(with: .kilo))
  }

  private func readLatestHeight() async throws -> Double? {
    let heightType = HKQuantityType.quantityType(forIdentifier: .height)!
    return try await readLatestQuantity(for: heightType, unit: .meter())
  }

  private func readQuantitySum(for quantityType: HKQuantityType, from startDate: Date, to endDate: Date, unit: HKUnit) async throws -> Double? {
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

    return try await withCheckedThrowingContinuation { continuation in
      let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let sum = result?.sumQuantity() {
          continuation.resume(returning: sum.doubleValue(for: unit))
        } else {
          continuation.resume(returning: nil)
        }
      }
      healthStore.execute(query)
    }
  }

  private func readLatestQuantity(for quantityType: HKQuantityType, unit: HKUnit) async throws -> Double? {
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

    return try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(sampleType: quantityType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let sample = samples?.first as? HKQuantitySample {
          continuation.resume(returning: sample.quantity.doubleValue(for: unit))
        } else {
          continuation.resume(returning: nil)
        }
      }
      healthStore.execute(query)
    }
  }

  private func mapSleepSamples(_ samples: [HKCategorySample]) -> ([SleepSegment], Int) {
    var segments: [SleepSegment] = []
    var totalMinutes: Double = 0

    for s in samples {
      let state: SleepSegment.State
      switch s.value {
      case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
        HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
        state = .asleep
        totalMinutes += s.endDate.timeIntervalSince(s.startDate) / 60.0
      case HKCategoryValueSleepAnalysis.inBed.rawValue:
        state = .inBed
      default:
        state = .awake
      }

      segments.append(
        SleepSegment(startDate: s.startDate, endDate: s.endDate, state: state)
      )
    }
    return (segments, Int(totalMinutes.rounded()))
  }

  private func readSleepAnalysis(from startDate: Date, to endDate: Date) async throws -> [HKCategorySample]? {
    let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

    return try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let samples = samples as? [HKCategorySample] {
          continuation.resume(returning: samples)
        } else {
          continuation.resume(returning: nil)
        }
      }
      healthStore.execute(query)
    }
  }

  private func readMindfulMinutes(from startDate: Date, to endDate: Date) async throws -> Double? {
    let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession)!
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    return try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let samples = samples as? [HKCategorySample] {
          let totalMinutes = samples.reduce(0.0) { acc, s in
            acc + s.endDate.timeIntervalSince(s.startDate) / 60.0
          }
          continuation.resume(returning: totalMinutes)
        } else {
          continuation.resume(returning: nil)
        }
      }
      healthStore.execute(query)
    }
  }

  // MARK: - Mock Data for Simulator
  private func generateMockHealthData() -> HealthData {
    let now = Date()

    // 랜덤하지만 현실적인 값들 생성
    let mockStepCount = Double.random(in: 3000...12000)
    let mockHeartRate = Double.random(in: 60...100)
    let mockActiveEnergy = Double.random(in: 200...800)
    let mockDistance = Double.random(in: 2000...10000) // 미터 단위
    let mockBodyMass = Double.random(in: 50...90) // kg
    let mockHeight = Double.random(in: 1.5...1.9) // 미터
    let mockMindfulMinutes = Double.random(in: 0...60)

    // 모의 수면 데이터
    let sleepStart = Calendar.current.date(byAdding: .hour, value: -8, to: now) ?? now
    let sleepEnd = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now

    let mockSleepSegments = [
      SleepSegment(startDate: sleepStart, endDate: sleepEnd, state: .asleep)
    ]
    let mockTotalSleepMinutes = Int(sleepEnd.timeIntervalSince(sleepStart) / 60)

    return HealthData(
      stepCount: mockStepCount,
      heartRate: mockHeartRate,
      activeEnergyBurned: mockActiveEnergy,
      distanceWalkingRunning: mockDistance,
      bodyMass: mockBodyMass,
      height: mockHeight,
      mindfulMinutes: mockMindfulMinutes,
      sleepSegments: mockSleepSegments,
      totalSleepMinutes: mockTotalSleepMinutes,
      timestamp: now
    )
  }

  enum HealthDataError: Error, LocalizedError {
    case healthDataNotAvailable
    case authorizationDenied

    var errorDescription: String? {
      switch self {
      case .healthDataNotAvailable:
        return "Health data is not available on this device"
      case .authorizationDenied:
        return "Health data access was denied"
      }
    }
  }
}
