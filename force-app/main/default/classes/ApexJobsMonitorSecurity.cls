/**
 * Apex Jobs & Async Monitor
 * Copyright (c) 2026 Jyotishko Roy (https://orcid.org/0009-0000-2837-4731)
 * Released under the MIT License. See LICENSE.
 */
public with sharing class ApexJobsMonitorSecurity {

    public class AccessInfo {
        @AuraEnabled public Boolean canReadAsyncJobs;
        @AuraEnabled public Boolean canReadScheduledJobs;
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=true)
    public static AccessInfo getAccessInfo() {
        AccessInfo info = new AccessInfo();
        info.canReadAsyncJobs = Schema.sObjectType.AsyncApexJob.isAccessible();
        info.canReadScheduledJobs = Schema.sObjectType.CronTrigger.isAccessible();

        if (!info.canReadAsyncJobs && !info.canReadScheduledJobs) {
            info.message = 'Insufficient access. Ask an admin to grant "View Setup and Configuration" (and optionally "Manage Apex Jobs").';
        } else if (!info.canReadAsyncJobs) {
            info.message = 'Limited access. Async jobs are not visible to your user. Ask an admin to grant "View Setup and Configuration".';
        } else if (!info.canReadScheduledJobs) {
            info.message = 'Limited access. Scheduled jobs are not visible to your user. Ask an admin to grant "View Setup and Configuration".';
        }
        return info;
    }

    public static void ensureAsyncReadable() {
        if (!Schema.sObjectType.AsyncApexJob.isAccessible()) {
            throw new AuraHandledException('You do not have access to AsyncApexJob. Ask an admin for "View Setup and Configuration".');
        }
    }

    public static void ensureCronReadable() {
        if (!Schema.sObjectType.CronTrigger.isAccessible()) {
            throw new AuraHandledException('You do not have access to scheduled jobs (CronTrigger). Ask an admin for "View Setup and Configuration".');
        }
    }
}
