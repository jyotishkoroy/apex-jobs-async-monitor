/**
 * Apex Jobs & Async Monitor
 * Copyright (c) 2026 Jyotishko Roy (https://orcid.org/0009-0000-2837-4731)
 * Released under the MIT License. See LICENSE.
 */
public with sharing class ApexJobsMonitorService {

    // --- DTOs ---------------------------------------------------------------

    public class Summary {
        @AuraEnabled public Integer totalJobs;
        @AuraEnabled public Integer activeJobs;
        @AuraEnabled public Integer failedJobs;
        @AuraEnabled public Integer abortedJobs;
        @AuraEnabled public Integer errorJobs;
        @AuraEnabled public Map<String, Integer> byStatus;
        @AuraEnabled public Map<String, Integer> byType;
    }

    public class AsyncJobRow {
        @AuraEnabled public String id;
        @AuraEnabled public String status;
        @AuraEnabled public String jobType;
        @AuraEnabled public String apexClassName;
        @AuraEnabled public String createdByName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Datetime completedDate;
        @AuraEnabled public Integer totalJobItems;
        @AuraEnabled public Integer jobItemsProcessed;
        @AuraEnabled public Integer numberOfErrors;
        @AuraEnabled public String extendedStatus;
        @AuraEnabled public String parentJobId;
    }

    public class AsyncJobDetail {
        @AuraEnabled public AsyncJobRow job;
        @AuraEnabled public String apexClassId;
    }

    public class ScheduledJobRow {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String state;
        @AuraEnabled public String jobType;
        @AuraEnabled public Datetime nextFireTime;
        @AuraEnabled public Datetime previousFireTime;
        @AuraEnabled public Integer timesTriggered;
        @AuraEnabled public String cronExpression;
        @AuraEnabled public Datetime startTime;
        @AuraEnabled public Datetime endTime;
    }

    // --- Query Methods ------------------------------------------------------

    public static Summary getSummary(Integer hoursBack) {
        ApexJobsMonitorSecurity.ensureAsyncReadable();

        Integer safeHours = (hoursBack == null || hoursBack <= 0 || hoursBack > 168) ? 24 : hoursBack; // cap at 7 days
        Datetime startDt = System.now().addHours(-safeHours);

        Summary outp = new Summary();
        outp.byStatus = new Map<String, Integer>();
        outp.byType = new Map<String, Integer>();

        // Status rollup
        for (AggregateResult ar : [
            SELECT Status s, COUNT(Id) c
            FROM AsyncApexJob
            WHERE CreatedDate >= :startDt
            GROUP BY Status
        ]) {
            outp.byStatus.put((String)ar.get('s'), (Integer)ar.get('c'));
        }

        // JobType rollup
        for (AggregateResult ar : [
            SELECT JobType t, COUNT(Id) c
            FROM AsyncApexJob
            WHERE CreatedDate >= :startDt
            GROUP BY JobType
        ]) {
            outp.byType.put((String)ar.get('t'), (Integer)ar.get('c'));
        }

        outp.totalJobs = 0;
        for (Integer c : outp.byStatus.values()) {
            outp.totalJobs += c;
        }

        outp.activeJobs = safeGet(outp.byStatus, 'Processing')
            + safeGet(outp.byStatus, 'Queued')
            + safeGet(outp.byStatus, 'Preparing')
            + safeGet(outp.byStatus, 'Holding')
            + safeGet(outp.byStatus, 'Acquired');

        outp.failedJobs = safeGet(outp.byStatus, 'Failed');
        outp.abortedJobs = safeGet(outp.byStatus, 'Aborted');

        // "Error jobs" includes jobs with NumberOfErrors > 0 OR Failed status.
        outp.errorJobs = outp.failedJobs;
        outp.errorJobs += (Integer)[
            SELECT COUNT(Id) c
            FROM AsyncApexJob
            WHERE CreatedDate >= :startDt
              AND NumberOfErrors > 0
        ].get(0).get('c');

        return outp;
    }

    public static List<AsyncJobRow> getAsyncJobs(
        String status,
        String jobType,
        Boolean errorsOnly,
        String searchTerm,
        Integer daysBack,
        Integer limitSize
    ) {
        ApexJobsMonitorSecurity.ensureAsyncReadable();

        Integer safeDays = (daysBack == null || daysBack <= 0 || daysBack > 30) ? 7 : daysBack;
        Integer safeLimit = (limitSize == null || limitSize <= 0 || limitSize > 500) ? 200 : limitSize;
        Datetime startDt = System.now().addDays(-safeDays);

        String cleanStatus = sanitizeEnum(status, allowedStatuses());
        String cleanType = sanitizeEnum(jobType, allowedJobTypes());
        Boolean onlyErrors = errorsOnly == true;

        String q = ''
            + 'SELECT Id, Status, JobType, ApexClassId, ApexClass.Name, CreatedBy.Name, '
            + 'CreatedDate, CompletedDate, TotalJobItems, JobItemsProcessed, NumberOfErrors, '
            + 'ExtendedStatus, ParentJobId '
            + 'FROM AsyncApexJob '
            + 'WHERE CreatedDate >= :startDt ';

        if (cleanStatus != null) {
            q += 'AND Status = \''
                + String.escapeSingleQuotes(cleanStatus)
                + '\' ';
        }
        if (cleanType != null) {
            q += 'AND JobType = \''
                + String.escapeSingleQuotes(cleanType)
                + '\' ';
        }
        if (onlyErrors) {
            q += 'AND (NumberOfErrors > 0 OR Status = \'Failed\') ';
        }
        String likeClause = buildLike(searchTerm);
        if (likeClause != null) {
            q += 'AND (Id LIKE ' + likeClause + ' OR ApexClass.Name LIKE ' + likeClause + ') ';
        }

        q += 'ORDER BY CreatedDate DESC LIMIT :safeLimit';

        List<AsyncApexJob> rows = Database.query(q);

        // FLS-safe projection (defensive; Setup objects are typically controlled via setup permissions).
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, rows);

        List<AsyncJobRow> outp = new List<AsyncJobRow>();
        for (SObject sob : decision.getRecords()) {
            AsyncApexJob j = (AsyncApexJob)sob;
            AsyncJobRow dto = new AsyncJobRow();
            dto.id = (String)j.get('Id');
            dto.status = (String)j.get('Status');
            dto.jobType = (String)j.get('JobType');
            dto.apexClassName = (j.getSObject('ApexClass') != null) ? (String)j.getSObject('ApexClass').get('Name') : null;
            dto.createdByName = (j.getSObject('CreatedBy') != null) ? (String)j.getSObject('CreatedBy').get('Name') : null;
            dto.createdDate = (Datetime)j.get('CreatedDate');
            dto.completedDate = (Datetime)j.get('CompletedDate');
            dto.totalJobItems = (Integer)j.get('TotalJobItems');
            dto.jobItemsProcessed = (Integer)j.get('JobItemsProcessed');
            dto.numberOfErrors = (Integer)j.get('NumberOfErrors');
            dto.extendedStatus = (String)j.get('ExtendedStatus');
            dto.parentJobId = (String)j.get('ParentJobId');
            outp.add(dto);
        }
        return outp;
    }

    public static AsyncJobDetail getAsyncJobDetail(String jobId) {
        ApexJobsMonitorSecurity.ensureAsyncReadable();

        if (String.isBlank(jobId)) {
            throw new AuraHandledException('Job Id is required.');
        }

        AsyncApexJob j = [
            SELECT Id, Status, JobType, ApexClassId, ApexClass.Name, CreatedBy.Name,
                   CreatedDate, CompletedDate, TotalJobItems, JobItemsProcessed, NumberOfErrors,
                   ExtendedStatus, ParentJobId
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];

        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, new List<AsyncApexJob>{ j });
        AsyncApexJob safeJ = (AsyncApexJob)decision.getRecords()[0];

        AsyncJobDetail d = new AsyncJobDetail();
        d.apexClassId = (String)safeJ.get('ApexClassId');

        AsyncJobRow dto = new AsyncJobRow();
        dto.id = (String)safeJ.get('Id');
        dto.status = (String)safeJ.get('Status');
        dto.jobType = (String)safeJ.get('JobType');
        dto.apexClassName = (safeJ.getSObject('ApexClass') != null) ? (String)safeJ.getSObject('ApexClass').get('Name') : null;
        dto.createdByName = (safeJ.getSObject('CreatedBy') != null) ? (String)safeJ.getSObject('CreatedBy').get('Name') : null;
        dto.createdDate = (Datetime)safeJ.get('CreatedDate');
        dto.completedDate = (Datetime)safeJ.get('CompletedDate');
        dto.totalJobItems = (Integer)safeJ.get('TotalJobItems');
        dto.jobItemsProcessed = (Integer)safeJ.get('JobItemsProcessed');
        dto.numberOfErrors = (Integer)safeJ.get('NumberOfErrors');
        dto.extendedStatus = (String)safeJ.get('ExtendedStatus');
        dto.parentJobId = (String)safeJ.get('ParentJobId');

        d.job = dto;
        return d;
    }

    public static List<ScheduledJobRow> getScheduledJobs(
        String state,
        String searchTerm,
        Integer limitSize
    ) {
        ApexJobsMonitorSecurity.ensureCronReadable();

        Integer safeLimit = (limitSize == null || limitSize <= 0 || limitSize > 500) ? 200 : limitSize;
        String cleanState = sanitizeEnum(state, allowedCronStates());

        String q = ''
            + 'SELECT Id, State, NextFireTime, PreviousFireTime, TimesTriggered, CronExpression, StartTime, EndTime, '
            + 'CronJobDetail.Name, CronJobDetail.JobType '
            + 'FROM CronTrigger '
            + 'WHERE CronJobDetailId != null ';

        if (cleanState != null) {
            q += 'AND State = \''
                + String.escapeSingleQuotes(cleanState)
                + '\' ';
        }

        String likeClause = buildLike(searchTerm);
        if (likeClause != null) {
            q += 'AND (CronJobDetail.Name LIKE ' + likeClause + ') ';
        }

        q += 'ORDER BY NextFireTime ASC NULLS LAST, CronJobDetail.Name ASC LIMIT :safeLimit';

        List<CronTrigger> rows = Database.query(q);
        SObjectAccessDecision decision = Security.stripInaccessible(AccessType.READABLE, rows);

        List<ScheduledJobRow> outp = new List<ScheduledJobRow>();
        for (SObject sob : decision.getRecords()) {
            CronTrigger ct = (CronTrigger)sob;
            ScheduledJobRow dto = new ScheduledJobRow();
            dto.id = (String)ct.get('Id');
            dto.state = (String)ct.get('State');
            dto.nextFireTime = (Datetime)ct.get('NextFireTime');
            dto.previousFireTime = (Datetime)ct.get('PreviousFireTime');
            dto.timesTriggered = (Integer)ct.get('TimesTriggered');
            dto.cronExpression = (String)ct.get('CronExpression');
            dto.startTime = (Datetime)ct.get('StartTime');
            dto.endTime = (Datetime)ct.get('EndTime');

            SObject cjd = ct.getSObject('CronJobDetail');
            dto.name = (cjd != null) ? (String)cjd.get('Name') : null;
            dto.jobType = (cjd != null) ? (String)cjd.get('JobType') : null;

            outp.add(dto);
        }
        return outp;
    }

    public static String abortJob(String jobId) {
        ApexJobsMonitorSecurity.ensureAsyncReadable();

        if (String.isBlank(jobId)) {
            throw new AuraHandledException('Job Id is required.');
        }

        try {
            System.abortJob(jobId);
            return 'Abort requested. Refresh to see updated status.';
        } catch (Exception e) {
            // Common causes: insufficient permission, job already complete, invalid id.
            throw new AuraHandledException('Unable to abort job. ' + e.getMessage());
        }
    }

    // --- Helpers ------------------------------------------------------------

    private static Integer safeGet(Map<String, Integer> m, String key) {
        return (m != null && m.containsKey(key) && m.get(key) != null) ? m.get(key) : 0;
    }

    private static String sanitizeEnum(String value, Set<String> allowed) {
        if (String.isBlank(value)) return null;
        String v = value.trim();
        return (allowed != null && allowed.contains(v)) ? v : null;
    }

    private static Set<String> allowedStatuses() {
        return new Set<String>{
            'Queued','Processing','Completed','Aborted','Failed','Holding','Preparing','Acquired'
        };
    }

    private static Set<String> allowedJobTypes() {
        // AsyncApexJob.JobType can vary across features; keep a broad-but-safe allow-list.
        return new Set<String>{
            'BatchApex','Queueable','Future','ScheduledApex','ApexSharingRecalculation','BatchApexWorker','TestRequest'
        };
    }

    private static Set<String> allowedCronStates() {
        // Values are stable across orgs; surfaced in Setup -> Scheduled Jobs UI.
        return new Set<String>{ 'WAITING','ACQUIRED','EXECUTING','COMPLETE','PAUSED','DELETED','ERROR' };
    }

    private static String buildLike(String term) {
        if (String.isBlank(term)) return null;
        String t = term.trim();
        if (t.length() < 2) return null; // keep queries selective
        t = t.replace('%','').replace('_','');
        t = String.escapeSingleQuotes('%' + t + '%');
        return '\'' + t + '\'';
    }
}
