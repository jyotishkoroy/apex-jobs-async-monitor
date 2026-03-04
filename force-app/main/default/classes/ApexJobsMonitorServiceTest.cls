/**
 * Apex Jobs & Async Monitor
 * Copyright (c) 2026 Jyotishko Roy (https://orcid.org/0009-0000-2837-4731)
 * Released under the MIT License. See LICENSE.
 */
@IsTest
private class ApexJobsMonitorServiceTest {

    private class SmokeQueueable implements Queueable {
        public void execute(QueueableContext qc) {
            // no-op
        }
    }

    private class SmokeBatch implements Database.Batchable<SObject> {
        public Database.QueryLocator start(Database.BatchableContext bc) {
            return Database.getQueryLocator('SELECT Id FROM User LIMIT 1');
        }
        public void execute(Database.BatchableContext bc, List<SObject> scope) {
            // no-op
        }
        public void finish(Database.BatchableContext bc) {
            // no-op
        }
    }

    private class SmokeSchedulable implements Schedulable {
        public void execute(SchedulableContext sc) {
            // no-op
        }
    }

    @IsTest
    static void testQueriesReturnDataAndDoNotThrow() {
        Test.startTest();
        System.enqueueJob(new SmokeQueueable());
        Database.executeBatch(new SmokeBatch(), 1);

        // Schedule far-future so it won't actually run in test, but CronTrigger is created.
        String cron = '0 0 0 1 1 ? 2099';
        System.schedule('ApexJobsMonitor_Test_' + String.valueOf(System.now().getTime()), cron, new SmokeSchedulable());
        Test.stopTest();

        ApexJobsMonitorService.Summary s = ApexJobsMonitorService.getSummary(24);
        System.assertNotEquals(null, s, 'Summary should be returned');
        System.assertNotEquals(null, s.byStatus, 'Status map should be returned');

        List<ApexJobsMonitorService.AsyncJobRow> jobs =
            ApexJobsMonitorService.getAsyncJobs(null, null, false, null, 7, 50);
        System.assertNotEquals(null, jobs, 'Jobs list should be returned');
        System.assert(jobs.size() > 0, 'Expected at least one async job created during test');

        List<ApexJobsMonitorService.ScheduledJobRow> sched =
            ApexJobsMonitorService.getScheduledJobs(null, null, 50);
        System.assertNotEquals(null, sched, 'Scheduled jobs list should be returned');
        System.assert(sched.size() > 0, 'Expected at least one scheduled job created during test');
    }
}
