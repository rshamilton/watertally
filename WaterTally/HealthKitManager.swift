//
//  HealthKitManager.swift
//  Water Tally
//
//  Thin wrapper around HealthKit. Water Tally only ever touches dietary water.
//  Every sample Water Tally writes carries the log's UUID as HKMetadataKeyExternalUUID so it can
//  be edited, deleted and de-duplicated exactly (no time/amount guessing).
//

import Foundation
import HealthKit
import Combine

struct HealthWaterSample {
    let externalID: UUID?     // Water Tally log id, when Water Tally wrote the sample
    let sampleID: UUID
    let ounces: Double
    let date: Date
    let sourceName: String
    let writtenByThisApp: Bool
}

final class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!

    /// True when the user has allowed Water Tally to write water to Health.
    @Published private(set) var isAuthorized = false

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    init() { refreshAuthorization() }

    var authorizationStatus: HKAuthorizationStatus {
        healthStore.authorizationStatus(for: waterType)
    }

    func refreshAuthorization() {
        let authorized = isAvailable && authorizationStatus == .sharingAuthorized
        if authorized != isAuthorized { isAuthorized = authorized }
    }

    // MARK: Authorization

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard isAvailable else { completion(false); return }
        healthStore.requestAuthorization(toShare: [waterType], read: [waterType]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refreshAuthorization()
                completion(self?.isAuthorized ?? false)
            }
        }
    }

    // MARK: Writing

    private func makeSample(for log: WaterLog) -> HKQuantitySample {
        let quantity = HKQuantity(unit: .liter(), doubleValue: log.fluidOunces * Volume.litersPerOunce)
        let metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: true,
            HKMetadataKeyExternalUUID: log.id.uuidString,
            "EntryName": log.buttonName
        ]
        return HKQuantitySample(type: waterType, quantity: quantity,
                                start: log.timestamp, end: log.timestamp, metadata: metadata)
    }

    /// Saves logs in batches. Calls back once with the ids that were written successfully.
    func save(_ logs: [WaterLog], completion: @escaping (Set<UUID>) -> Void) {
        guard isAuthorized, !logs.isEmpty else { completion([]); return }

        let batches = stride(from: 0, to: logs.count, by: 100).map { Array(logs[$0..<min($0 + 100, logs.count)]) }
        var saved = Set<UUID>()
        let group = DispatchGroup()
        let lock = NSLock()

        for batch in batches {
            group.enter()
            healthStore.save(batch.map(makeSample)) { success, _ in
                if success {
                    lock.lock(); saved.formUnion(batch.map(\.id)); lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(saved) }
    }

    // MARK: Deleting

    /// Deletes Water Tally's own samples for a log. Uses the external id first and falls back to a
    /// tight time/amount match for entries written by early builds that had no external id.
    func delete(log: WaterLog, completion: @escaping (Bool) -> Void) {
        guard isAuthorized else { completion(false); return }

        let byID = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyExternalUUID,
                                               allowedValues: [log.id.uuidString])
        healthStore.deleteObjects(of: waterType, predicate: byID) { [weak self] success, count, _ in
            guard let self else { return }
            if success && count > 0 {
                DispatchQueue.main.async { completion(true) }
                return
            }
            self.deleteLegacySample(for: log, completion: completion)
        }
    }

    private func deleteLegacySample(for log: WaterLog, completion: @escaping (Bool) -> Void) {
        let window = HKQuery.predicateForSamples(withStart: log.timestamp.addingTimeInterval(-2),
                                                 end: log.timestamp.addingTimeInterval(2),
                                                 options: .strictStartDate)
        let ours = HKQuery.predicateForObjects(from: HKSource.default())
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [window, ours])
        let expectedLiters = log.fluidOunces * Volume.litersPerOunce

        let query = HKSampleQuery(sampleType: waterType, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
            let match = (samples as? [HKQuantitySample])?.first {
                abs($0.quantity.doubleValue(for: .liter()) - expectedLiters) < 0.002
            }
            guard let self, let match else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            self.healthStore.delete(match) { success, _ in
                DispatchQueue.main.async { completion(success) }
            }
        }
        healthStore.execute(query)
    }

    /// Removes every water sample Water Tally has written (used by "Delete All Data").
    func deleteAllOwnSamples(completion: @escaping (Bool) -> Void) {
        guard isAuthorized else { completion(false); return }
        let ours = HKQuery.predicateForObjects(from: HKSource.default())
        healthStore.deleteObjects(of: waterType, predicate: ours) { success, _, _ in
            completion(success)
        }
    }

    /// Replaces the stored sample for an edited log.
    func replace(log: WaterLog, previous: WaterLog, completion: @escaping (Bool) -> Void) {
        delete(log: previous) { [weak self] _ in
            guard let self else { return }
            self.save([log]) { saved in completion(saved.contains(log.id)) }
        }
    }

    // MARK: Reading (manual restore only)

    func fetchSamples(since start: Date, completion: @escaping ([HealthWaterSample]) -> Void) {
        guard isAuthorized else { completion([]); return }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: waterType, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            let results = (samples as? [HKQuantitySample] ?? []).map { sample -> HealthWaterSample in
                let external = (sample.metadata?[HKMetadataKeyExternalUUID] as? String).flatMap(UUID.init(uuidString:))
                let name = sample.metadata?["EntryName"] as? String
                    ?? sample.sourceRevision.source.name
                return HealthWaterSample(
                    externalID: external,
                    sampleID: sample.uuid,
                    ounces: sample.quantity.doubleValue(for: .liter()) / Volume.litersPerOunce,
                    date: sample.startDate,
                    sourceName: name,
                    writtenByThisApp: sample.sourceRevision.source == HKSource.default()
                )
            }
            DispatchQueue.main.async { completion(results) }
        }
        healthStore.execute(query)
    }
}
