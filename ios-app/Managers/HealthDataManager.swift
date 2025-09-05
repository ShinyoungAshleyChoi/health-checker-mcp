import Foundation
import HealthKit
import SwiftUI

final class HealthDataManager: ObservableObject {
  // MARK: - First-install full history upload (send each sample individually)
  public func sendInitialHistoricalDataIfNeeded(
    daysBack: Int = 30,
    sendFunction: @escaping @Sendable (HealthData) async throws -> Void
  ) async {
    let flagKey = "initialUploadDone"
    if UserDefaults.standard.bool(forKey: flagKey) {
      print("[HealthDataManager] Initial upload already completed. Skipping.")
      return
    }

    let now = Date()
    guard let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: now) else { return }

    do {
      try await sendFullHistoricalData(from: startDate, to: now, sendFunction: sendFunction)
      UserDefaults.standard.set(true, forKey: flagKey)
      print("[HealthDataManager] Initial full-history upload completed and flagged.")
    } catch {
      print("[HealthDataManager] Initial full-history upload failed: \(error)")
    }
  }

  private func sendFullHistoricalData(
    from startDate: Date,
    to endDate: Date,
    sendFunction: @escaping @Sendable (HealthData) async throws -> Void
  ) async throws {
    #if targetEnvironment(simulator)
    let mock = generateMockIncrementalHealthData(since: startDate)
    try await sendFunction(mock)
    print("[HealthDataManager] (Simulator) sent mock full-history batch as a single payload")
    return
    #else
    try await sendIndividualStepCountData(from: startDate, to: endDate, sendFunction: sendFunction)
    try await sendIndividualActiveEnergyData(from: startDate, to: endDate, sendFunction: sendFunction)
    try await sendIndividualDistanceData(from: startDate, to: endDate, sendFunction: sendFunction)

    try await sendIndividualHeartRateData(from: startDate, to: endDate, sendFunction: sendFunction)
    try await sendIndividualBodyMassData(from: startDate, to: endDate, sendFunction: sendFunction)
    try await sendIndividualHeightData(from: startDate, to: endDate, sendFunction: sendFunction)

    try await sendIndividualMindfulData(from: startDate, to: endDate, sendFunction: sendFunction)
    try await sendIndividualSleepData(from: startDate, to: endDate, sendFunction: sendFunction)
    #endif
  }

  // MARK: - Individual senders for first-install full history
  private func sendIndividualStepCountData(
    from startDate: Date, to endDate: Date,
    sendFunction: @escaping @Sendable (HealthData) async throws -> Void
  ) async throws {
    let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

    return try await withCheckedThrowingContinuation { continuation in
      let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
        if let error = error { continuation.resume(throwing: error); return }
        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { continuation.resume(); return }
        Task {
          for s in samples {
            let payload = HealthData(
              stepCount: s.quantity.doubleValue(for: .count()),
              heartRate: nil,
              activeEnergyBurned: nil,
              distanceWalkingRunning: nil,
              bodyMass: nil,
              height: nil,
              mindfulMinutes: nil,
              sleepSegments: nil,
              totalSleepMinutes: nil,
              timestamp: s.endDate,
              isIncremental: true,
              sinceDate: startDate
            )
            do { try await sendFunction(payload) } catch { print("[HealthDataManager] Step sample send failed: \(error)") }
          }
          continuation.resume()
        }
      }
      healthStore.execute(q)
    }
  }

  private func sendIndividualActiveEnergyData(
    from startDate: Date, to endDate: Date,
    sendFunction: @escaping @Sendable (HealthData) async throws -> Void
  ) async throws {
    let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

    return try await withCheckedThrowingContinuation { continuation in
      let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
        if let error = error { continuation.resume(throwing: error); return }
        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { continuation.resume(); return }
        Task {
          for s in samples {
            let payload = HealthData(
              stepCount: nil,
              heartRate: nil,
              activeEnergyBurned: s.quantity.doubleValue(for: .kilocalorie()),
              distanceWalkingRunning: nil,
              bodyMass: nil,
              height: nil,
              mindfulMinutes: nil,
              sleepSegments: nil,
              totalSleepMinutes: nil,
              timestamp: s.endDate,
              isIncremental: true,
              sinceDate: startDate
            )
            do { try await sendFunction(payload) } catch { print("[HealthDataManager] ActiveEnergy sample send failed: \(error)") }
          }
          continuation.resume()
        }
      }
      healthStore.execute(q)
    }
  }

  private func sendIndividualDistanceData(
    from startDate: Date, to endDate: Date,
    sendFunction: @escaping @Sendable (HealthData) async throws -> Void
  ) async throws {
    let type = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

    return try await withCheckedThrowingContinuation { continuation in
      let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
        if let error = error { continuation.resume(throwing: error); return }
        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { continuation.resume(); return }
        Task {
          for s in samples {
            let payload = HealthData(
              stepCount: nil,
              heartRate: nil,
              activeEnergyBurned: nil,
              distanceWalkingRunning: s.quantity.doubleValue(for: .meter()),
              bodyMass: nil,
              height: nil,
              mindfulMinutes: nil,
              sleepSegments: nil,
              totalSleepMinutes: nil,
              timestamp: s.endDate,
              isIncremental: true,
              sinceDate: startDate
            )
            do { try await sendFunction(payload) } catch { print("[HealthDataManager] Distance sample send failed: \(error)") }
          }
          continuation.resume()
        }
      }
      healthStore.execute(q)
    }
  }

  private func sendIndividualMindfulData(
    from startDate: Date, to endDate: Date,
    sendFunction: @escaping @Sendable (HealthData) async throws -> Void
  ) async throws {
    let type = HKCategoryType.categoryType(forIdentifier: .mindfulSession)!
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

    return try await withCheckedThrowingContinuation { continuation in
      let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
        if let error = error { continuation.resume(throwing: error); return }
        guard let samples = samples as? [HKCategorySample], !samples.isEmpty else { continuation.resume(); return }
        Task {
          for s in samples {
            let minutes = s.endDate.timeIntervalSince(s.startDate) / 60.0
            let payload = HealthData(
              stepCount: nil,
              heartRate: nil,
              activeEnergyBurned: nil,
              distanceWalkingRunning: nil,
              bodyMass: nil,
              height: nil,
              mindfulMinutes: minutes,
              sleepSegments: nil,
              totalSleepMinutes: nil,
              timestamp: s.endDate,
              isIncremental: true,
              sinceDate: startDate
            )
            do { try await sendFunction(payload) } catch { print("[HealthDataManager] Mindful sample send failed: \(error)") }
          }
          continuation.resume()
        }
      }
      healthStore.execute(q)
    }
  }

  private func sendIndividualSleepData(
    from startDate: Date, to endDate: Date,
    sendFunction: @escaping @Sendable (HealthData) async throws -> Void
  ) async throws {
    let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

    return try await withCheckedThrowingContinuation { continuation in
      let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
        if let error = error { continuation.resume(throwing: error); return }
        guard let samples = samples as? [HKCategorySample], !samples.isEmpty else { continuation.resume(); return }
        Task {
          for s in samples {
            let state: SleepSegment.State
            switch s.value {
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                 HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                 HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                 HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
              state = .asleep
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
              state = .inBed
            default:
              state = .awake
            }

            let seg = SleepSegment(startDate: s.startDate, endDate: s.endDate, state: state)
            let total = Int(s.endDate.timeIntervalSince(s.startDate) / 60.0)

            let payload = HealthData(
              stepCount: nil,
              heartRate: nil,
              activeEnergyBurned: nil,
              distanceWalkingRunning: nil,
              bodyMass: nil,
              height: nil,
              mindfulMinutes: nil,
              sleepSegments: [seg],
              totalSleepMinutes: total,
              timestamp: s.endDate,
              isIncremental: true,
              sinceDate: startDate
            )
            do { try await sendFunction(payload) } catch { print("[HealthDataManager] Sleep sample send failed: \(error)") }
          }
          continuation.resume()
        }
      }
      healthStore.execute(q)
    }
  }
  private let healthStore = HKHealthStore()
  private var observerQueries: [HKObserverQuery] = []

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
    // 시뮬레이터에서도 옵저버 설정
    setupHealthDataObservers()
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
          // 권한 허용 후 헬스데이터 변경 감지 시작
          self.setupHealthDataObservers()
          // [Optional] First-install full-history upload example:
          // Task {
          //   await self.sendInitialHistoricalDataIfNeeded(daysBack: 30) { payload in
          //     try await YourUploader.shared.send(payload)
          //   }
          // }
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

    // Resolve async lets before building the payload
    let sc = try await stepCount
    let hr = try await heartRate
    let ae = try await activeEnergy
    let dist = try await distance
    let bm = try await bodyMass
    let ht = try await height
    let mm = try await mindfulMinutes

    return HealthData(
      stepCount: sc,
      heartRate: hr,
      activeEnergyBurned: ae,
      distanceWalkingRunning: dist,
      bodyMass: bm,
      height: ht,
      mindfulMinutes: mm,
      sleepSegments: segments.isEmpty ? nil : segments,
      totalSleepMinutes: segments.isEmpty ? nil : total,
      timestamp: now,
      isIncremental: false // 전체 데이터
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

  // 증분 데이터 읽기 - 각 변동분을 개별 전송
  func readAndSendIncrementalHealthData(since lastSyncDate: Date, sendFunction: @escaping @Sendable (HealthData) async throws -> Void) async throws {
    // 시뮬레이터에서는 모의 증분 데이터 반환
    #if targetEnvironment(simulator)
    print("[HealthDataManager] 시뮬레이터에서 증분 데이터 생성 및 전송: \(lastSyncDate) 이후")
    let mock = generateMockIncrementalHealthData(since: lastSyncDate)
    try await sendFunction(mock)
    return
    #else
    let now = Date()

    // 1. 누적 데이터 (합계) - 한 번만 전송
    async let stepCount = readStepCount(from: lastSyncDate, to: now)
    async let activeEnergy = readActiveEnergy(from: lastSyncDate, to: now)
    async let distance = readDistance(from: lastSyncDate, to: now)
    async let sleepSamples = readSleepAnalysis(from: lastSyncDate, to: now)
    async let mindfulMinutes = readMindfulMinutes(from: lastSyncDate, to: now)

    // 누적 데이터 전송
    let samples = try await sleepSamples
    let (segments, total) = samples.map(mapSleepSamples) ?? ([], 0)

    let cumulativeData = HealthData(
      stepCount: try await stepCount,
      heartRate: nil, // 개별 전송할 예정
      activeEnergyBurned: try await activeEnergy,
      distanceWalkingRunning: try await distance,
      bodyMass: nil, // 개별 전송할 예정
      height: nil, // 개별 전송할 예정
      mindfulMinutes: try await mindfulMinutes,
      sleepSegments: segments.isEmpty ? nil : segments,
      totalSleepMinutes: segments.isEmpty ? nil : total,
      timestamp: now,
      isIncremental: true,
      sinceDate: lastSyncDate
    )

    // 누적 데이터 전송
    try await sendFunction(cumulativeData)
    print("[HealthDataManager] 누적 데이터 전송 완료")

    // 2. 개별 데이터들 - 각 측정값마다 개별 전송
    try await sendIndividualHeartRateData(from: lastSyncDate, to: now, sendFunction: sendFunction)
    try await sendIndividualBodyMassData(from: lastSyncDate, to: now, sendFunction: sendFunction)
    try await sendIndividualHeightData(from: lastSyncDate, to: now, sendFunction: sendFunction)
    #endif
  }

  // 개별 심박수 데이터 전송
  private func sendIndividualHeartRateData(from startDate: Date, to endDate: Date, sendFunction: @escaping @Sendable (HealthData) async throws -> Void) async throws {
    let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

    return try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let samples = samples as? [HKQuantitySample] {
          Task {
            for sample in samples {
              let heartRateData = HealthData(
                stepCount: nil,
                heartRate: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                activeEnergyBurned: nil,
                distanceWalkingRunning: nil,
                bodyMass: nil,
                height: nil,
                mindfulMinutes: nil,
                sleepSegments: nil,
                totalSleepMinutes: nil,
                timestamp: sample.endDate,
                isIncremental: true,
                sinceDate: startDate
              )

              do {
                try await sendFunction(heartRateData)
                print("[HealthDataManager] 개별 심박수 전송: \(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))) at \(sample.endDate)")
              } catch {
                print("[HealthDataManager] 개별 심박수 전송 실패: \(error)")
              }
            }
            continuation.resume()
          }
        } else {
          continuation.resume()
        }
      }
      healthStore.execute(query)
    }
  }

  // 개별 체중 데이터 전송
  private func sendIndividualBodyMassData(from startDate: Date, to endDate: Date, sendFunction: @escaping @Sendable (HealthData) async throws -> Void) async throws {
    let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

    return try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(sampleType: bodyMassType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let samples = samples as? [HKQuantitySample] {
          Task {
            for sample in samples {
              let bodyMassData = HealthData(
                stepCount: nil,
                heartRate: nil,
                activeEnergyBurned: nil,
                distanceWalkingRunning: nil,
                bodyMass: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)),
                height: nil,
                mindfulMinutes: nil,
                sleepSegments: nil,
                totalSleepMinutes: nil,
                timestamp: sample.endDate,
                isIncremental: true,
                sinceDate: startDate
              )

              do {
                try await sendFunction(bodyMassData)
                print("[HealthDataManager] 개별 체중 전송: \(sample.quantity.doubleValue(for: .gramUnit(with: .kilo)))kg at \(sample.endDate)")
              } catch {
                print("[HealthDataManager] 개별 체중 전송 실패: \(error)")
              }
            }
            continuation.resume()
          }
        } else {
          continuation.resume()
        }
      }
      healthStore.execute(query)
    }
  }

  // 개별 키 데이터 전송
  private func sendIndividualHeightData(from startDate: Date, to endDate: Date, sendFunction: @escaping @Sendable (HealthData) async throws -> Void) async throws {
    let heightType = HKQuantityType.quantityType(forIdentifier: .height)!
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

    return try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(sampleType: heightType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let samples = samples as? [HKQuantitySample] {
          Task {
            for sample in samples {
              let heightData = HealthData(
                stepCount: nil,
                heartRate: nil,
                activeEnergyBurned: nil,
                distanceWalkingRunning: nil,
                bodyMass: nil,
                height: sample.quantity.doubleValue(for: .meter()),
                mindfulMinutes: nil,
                sleepSegments: nil,
                totalSleepMinutes: nil,
                timestamp: sample.endDate,
                isIncremental: true,
                sinceDate: startDate
              )

              do {
                try await sendFunction(heightData)
                print("[HealthDataManager] 개별 키 전송: \(sample.quantity.doubleValue(for: .meter()))m at \(sample.endDate)")
              } catch {
                print("[HealthDataManager] 개별 키 전송 실패: \(error)")
              }
            }
            continuation.resume()
          }
        } else {
          continuation.resume()
        }
      }
      healthStore.execute(query)
    }
  }

  // HealthKit 데이터 변경 감지 설정
  private func setupHealthDataObservers() {
    print("[HealthDataManager] HealthKit 데이터 변경 감지 시작")

    #if targetEnvironment(simulator)
    print("[HealthDataManager] 시뮬레이터에서는 실제 옵저버 대신 시뮬레이션")
    return
    #endif

    // 기존 옵저버 정리
    observerQueries.forEach { healthStore.stop($0) }
    observerQueries.removeAll()

    // 각 데이터 타입에 대한 옵저버 설정
    for sampleType in healthDataTypes {
      let observerQuery = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] query, completionHandler, error in
        if let error = error {
          print("[HealthDataManager] 옵저버 오류: \(error.localizedDescription)")
          completionHandler()
          return
        }

        print("[HealthDataManager] HealthKit 데이터 변경 감지: \(sampleType.identifier)")

        // 백그라운드 전송 트리거
        Task { @MainActor in
          await BackgroundTaskManager.shared.triggerHealthDataSync()
        }

        completionHandler()
      }

      healthStore.execute(observerQuery)
      observerQueries.append(observerQuery)
    }

    // 백그라운드 전송 활성화
    for sampleType in healthDataTypes {
      if let quantityType = sampleType as? HKQuantityType {
        healthStore.enableBackgroundDelivery(for: quantityType, frequency: .immediate) { success, error in
          if success {
            print("[HealthDataManager] \(sampleType.identifier) 백그라운드 전송 활성화 성공")
          } else {
            print("[HealthDataManager] \(sampleType.identifier) 백그라운드 전송 활성화 실패: \(error?.localizedDescription ?? "알 수 없는 오류")")
          }
        }
      }
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
      timestamp: now,
      isIncremental: false // 전체 데이터
    )
  }

  // 시뮬레이터용 증분 모의 데이터 생성 (모든 중간 데이터 포함)
  private func generateMockIncrementalHealthData(since lastSyncDate: Date) -> HealthData {
    let now = Date()
    let timeSinceLastSync = now.timeIntervalSince(lastSyncDate)
    let hoursSinceLastSync = timeSinceLastSync / 3600

    print("[HealthDataManager] 증분 데이터 생성: \(hoursSinceLastSync)시간 경과")

    // 마지막 동기화 이후 시간에 비례한 증분 데이터 생성
    let incrementalSteps = Double.random(in: 100...500) * max(1, hoursSinceLastSync)
    let incrementalEnergy = Double.random(in: 10...50) * max(1, hoursSinceLastSync)
    let incrementalDistance = Double.random(in: 50...300) * max(1, hoursSinceLastSync)
    let incrementalMindful = hoursSinceLastSync > 1 ? Double.random(in: 0...15) : 0

    // 중간 데이터들 생성 (시간대별로 여러 측정값)
    let sampleCount = max(1, Int(hoursSinceLastSync))
    var allHeartRates: [Double] = []
    var allBodyMass: [Double] = []
    var allHeight: [Double] = []

    for i in 0..<sampleCount {
      allHeartRates.append(Double.random(in: 60...100))
      if Double.random(in: 0...1) > 0.7 { // 30% 확률로 체중 측정
        allBodyMass.append(Double.random(in: 68...72))
      }
      if Double.random(in: 0...1) > 0.9 { // 10% 확률로 키 측정
        allHeight.append(Double.random(in: 1.75...1.77))
      }
    }

    // 수면 데이터 (마지막 동기화 이후 수면이 있었다면)
    var sleepSegments: [SleepSegment]? = nil
    var totalSleepMinutes: Int? = nil

    if hoursSinceLastSync >= 6 { // 6시간 이상 경과했다면 수면 데이터 포함
      let sleepStart = Calendar.current.date(byAdding: .hour, value: -Int(hoursSinceLastSync), to: now) ?? lastSyncDate
      let sleepEnd = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now

      sleepSegments = [SleepSegment(startDate: sleepStart, endDate: sleepEnd, state: .asleep)]
      totalSleepMinutes = Int((sleepEnd.timeIntervalSince(sleepStart)) / 60)
    }

    return HealthData(
      stepCount: incrementalSteps,
      heartRate: allHeartRates.last,
      activeEnergyBurned: incrementalEnergy,
      distanceWalkingRunning: incrementalDistance,
      bodyMass: allBodyMass.last,
      height: allHeight.last,
      mindfulMinutes: incrementalMindful,
      sleepSegments: sleepSegments,
      totalSleepMinutes: totalSleepMinutes,
      timestamp: now,
      isIncremental: true,
      sinceDate: lastSyncDate
    )
  }
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

