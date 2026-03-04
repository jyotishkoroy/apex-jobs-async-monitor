/**
 * Apex Jobs & Async Monitor
 * Copyright (c) 2026 Jyotishko Roy (https://orcid.org/0009-0000-2837-4731)
 * Released under the MIT License. See LICENSE.
 */
public with sharing class ApexJobsMonitorController {

    @AuraEnabled(cacheable=true)
    public static ApexJobsMonitorSecurity.AccessInfo getAccessInfo() {
        return ApexJobsMonitorSecurity.getAccessInfo();
    }

    @AuraEnabled(cacheable=true)
    public static ApexJobsMonitorService.Summary getSummary(Integer hoursBack) {
        return ApexJobsMonitorService.getSummary(hoursBack);
    }

    @AuraEnabled(cacheable=true)
    public static List<ApexJobsMonitorService.AsyncJobRow> getAsyncJobs(
        String status,
        String jobType,
        Boolean errorsOnly,
        String searchTerm,
        Integer daysBack,
        Integer limitSize
    ) {
        return ApexJobsMonitorService.getAsyncJobs(status, jobType, errorsOnly, searchTerm, daysBack, limitSize);
    }

    @AuraEnabled(cacheable=true)
    public static ApexJobsMonitorService.AsyncJobDetail getAsyncJobDetail(String jobId) {
        return ApexJobsMonitorService.getAsyncJobDetail(jobId);
    }

    @AuraEnabled(cacheable=true)
    public static List<ApexJobsMonitorService.ScheduledJobRow> getScheduledJobs(
        String state,
        String searchTerm,
        Integer limitSize
    ) {
        return ApexJobsMonitorService.getScheduledJobs(state, searchTerm, limitSize);
    }

    @AuraEnabled
    public static String abortJob(String jobId) {
        return ApexJobsMonitorService.abortJob(jobId);
    }
}
