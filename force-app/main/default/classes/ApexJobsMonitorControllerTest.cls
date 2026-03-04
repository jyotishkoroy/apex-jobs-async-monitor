/**
 * Apex Jobs & Async Monitor
 * Copyright (c) 2026 Jyotishko Roy (https://orcid.org/0009-0000-2837-4731)
 * Released under the MIT License. See LICENSE.
 */
@IsTest
private class ApexJobsMonitorControllerTest {

    @IsTest
    static void testControllerSurface() {
        Test.startTest();
        ApexJobsMonitorSecurity.AccessInfo access = ApexJobsMonitorController.getAccessInfo();
        System.assertNotEquals(null, access, 'Access info should be returned');

        // Calls should not throw even if org is empty; test context creates async jobs in other tests.
        ApexJobsMonitorService.Summary s = ApexJobsMonitorController.getSummary(24);
        System.assertNotEquals(null, s, 'Summary should be returned');

        List<ApexJobsMonitorService.AsyncJobRow> jobs = ApexJobsMonitorController.getAsyncJobs(null, null, false, null, 7, 10);
        System.assertNotEquals(null, jobs, 'Jobs list should be returned');

        List<ApexJobsMonitorService.ScheduledJobRow> sched = ApexJobsMonitorController.getScheduledJobs(null, null, 10);
        System.assertNotEquals(null, sched, 'Scheduled jobs list should be returned');
        Test.stopTest();
    }
}
