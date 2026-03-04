import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getAccessInfo from '@salesforce/apex/ApexJobsMonitorController.getAccessInfo';
import getSummary from '@salesforce/apex/ApexJobsMonitorController.getSummary';
import getAsyncJobs from '@salesforce/apex/ApexJobsMonitorController.getAsyncJobs';
import getAsyncJobDetail from '@salesforce/apex/ApexJobsMonitorController.getAsyncJobDetail';
import getScheduledJobs from '@salesforce/apex/ApexJobsMonitorController.getScheduledJobs';
import abortJob from '@salesforce/apex/ApexJobsMonitorController.abortJob';

const DEFAULT_HOURS_BACK = 24;
const DEFAULT_DAYS_BACK = 7;
const DEFAULT_PAGE_SIZE = 200;
const AUTO_REFRESH_MS = 30000;

const STATUS_OPTIONS = [
    { label: 'All', value: 'ALL' },
    { label: 'Queued', value: 'Queued' },
    { label: 'Processing', value: 'Processing' },
    { label: 'Completed', value: 'Completed' },
    { label: 'Failed', value: 'Failed' },
    { label: 'Aborted', value: 'Aborted' },
    { label: 'Holding', value: 'Holding' },
    { label: 'Preparing', value: 'Preparing' }
];

const JOBTYPE_OPTIONS = [
    { label: 'All', value: 'ALL' },
    { label: 'Queueable', value: 'Queueable' },
    { label: 'Batch Apex', value: 'BatchApex' },
    { label: 'Future', value: 'Future' },
    { label: 'Scheduled Apex', value: 'ScheduledApex' }
];

const CRON_STATE_OPTIONS = [
    { label: 'All', value: 'ALL' },
    { label: 'WAITING', value: 'WAITING' },
    { label: 'ACQUIRED', value: 'ACQUIRED' },
    { label: 'EXECUTING', value: 'EXECUTING' },
    { label: 'COMPLETE', value: 'COMPLETE' },
    { label: 'PAUSED', value: 'PAUSED' },
    { label: 'DELETED', value: 'DELETED' },
    { label: 'ERROR', value: 'ERROR' }
];

export default class ApexJobsAsyncMonitor extends LightningElement {
    // Filters
    statusFilter = 'ALL';
    jobTypeFilter = 'ALL';
    errorsOnly = false;
    daysBack = DEFAULT_DAYS_BACK;
    pageSize = DEFAULT_PAGE_SIZE;
    hoursBack = DEFAULT_HOURS_BACK;
    asyncSearch = '';
    cronStateFilter = 'ALL';
    scheduledSearch = '';

    // Loading flags
    loadingAccess = true;
    loadingSummary = true;
    loadingAsync = true;
    loadingScheduled = true;

    // Auto refresh
    autoRefresh = false;
    _intervalId;

    // UI state
    @track asyncRows = [];
    @track scheduledRows = [];
    @track summary = null;
    @track accessInfo = null;

    @track detailOpen = false;
    @track detail = null;
    @track detailLoading = false;

    // Wired results for refresh
    wiredAccess;
    wiredSummary;
    wiredAsync;
    wiredScheduled;

    columnsScheduled = [
        { label: 'Name', fieldName: 'name', type: 'text' },
        { label: 'State', fieldName: 'state', type: 'text' },
        { label: 'Type', fieldName: 'jobType', type: 'text' },
        {
            label: 'Next Fire',
            fieldName: 'nextFireTime',
            type: 'date',
            typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }
        },
        {
            label: 'Previous Fire',
            fieldName: 'previousFireTime',
            type: 'date',
            typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }
        },
        { label: 'Times Triggered', fieldName: 'timesTriggered', type: 'number' }
    ];

    get columnsAsync() {
        const boundRowActions = this.getAsyncRowActions.bind(this);
        return [
            {
                label: 'Status',
                fieldName: 'status',
                type: 'text',
                cellAttributes: { class: { fieldName: 'statusClass' } }
            },
            { label: 'Type', fieldName: 'jobType', type: 'text' },
            { label: 'Apex Class', fieldName: 'apexClassName', type: 'text' },
            {
                label: 'Submitted',
                fieldName: 'createdDate',
                type: 'date',
                typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }
            },
            {
                label: 'Completed',
                fieldName: 'completedDate',
                type: 'date',
                typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }
            },
            { label: 'Progress', fieldName: 'progress', type: 'text' },
            { label: 'Errors', fieldName: 'numberOfErrors', type: 'number', cellAttributes: { class: { fieldName: 'errorClass' } } },
            { type: 'action', typeAttributes: { rowActions: boundRowActions } }
        ];
    }

    get statusOptions() { return STATUS_OPTIONS; }
    get jobTypeOptions() { return JOBTYPE_OPTIONS; }
    get cronStateOptions() { return CRON_STATE_OPTIONS; }

    get statusParam() { return this.statusFilter === 'ALL' ? null : this.statusFilter; }
    get jobTypeParam() { return this.jobTypeFilter === 'ALL' ? null : this.jobTypeFilter; }
    get asyncSearchParam() { return this.asyncSearch?.trim() ? this.asyncSearch.trim() : null; }
    get cronStateParam() { return this.cronStateFilter === 'ALL' ? null : this.cronStateFilter; }
    get scheduledSearchParam() { return this.scheduledSearch?.trim() ? this.scheduledSearch.trim() : null; }

    get hasAccessWarning() { return this.accessInfo?.message; }

    get isLoading() {
        return Boolean(this.loadingAccess || this.loadingSummary || this.loadingAsync || this.loadingScheduled || this.detailLoading);
    }

    // --- Wires -------------------------------------------------------------

    @wire(getAccessInfo)
    wiredAccessInfo(result) {
        this.wiredAccess = result;
        const { data, error } = result;
        this.loadingAccess = !(data || error);

        if (data) {
            this.accessInfo = data;
        } else if (error) {
            this.accessInfo = { message: this.reduceError(error) };
        }
    }

    @wire(getSummary, { hoursBack: '$hoursBack' })
    wiredSummaryInfo(result) {
        this.wiredSummary = result;
        const { data, error } = result;
        this.loadingSummary = !(data || error);

        if (data) {
            this.summary = this.decorateSummary(data);
        } else if (error) {
            this.summary = null;
            this.toast('Summary error', this.reduceError(error), 'error');
        }
    }

    @wire(getAsyncJobs, {
        status: '$statusParam',
        jobType: '$jobTypeParam',
        errorsOnly: '$errorsOnly',
        searchTerm: '$asyncSearchParam',
        daysBack: '$daysBack',
        limitSize: '$pageSize'
    })
    wiredAsyncJobs(result) {
        this.wiredAsync = result;
        const { data, error } = result;
        this.loadingAsync = !(data || error);

        if (data) {
            this.asyncRows = this.decorateAsyncRows(data);
        } else if (error) {
            this.asyncRows = [];
            this.toast('Async jobs error', this.reduceError(error), 'error');
        }
    }

    @wire(getScheduledJobs, {
        state: '$cronStateParam',
        searchTerm: '$scheduledSearchParam',
        limitSize: '$pageSize'
    })
    wiredScheduledJobs(result) {
        this.wiredScheduled = result;
        const { data, error } = result;
        this.loadingScheduled = !(data || error);

        if (data) {
            this.scheduledRows = data;
        } else if (error) {
            this.scheduledRows = [];
            this.toast('Scheduled jobs error', this.reduceError(error), 'error');
        }
    }

    disconnectedCallback() {
        this.clearInterval();
    }

    // --- UI Handlers -------------------------------------------------------

    handleRefresh() {
        this.refreshAll();
    }

    handleToggleAutoRefresh(event) {
        this.autoRefresh = event.target.checked;
        if (this.autoRefresh) {
            this._intervalId = setInterval(() => {
                this.refreshAll(false);
            }, AUTO_REFRESH_MS);
            this.toast('Auto-refresh enabled', 'Refreshing every 30 seconds.', 'info');
        } else {
            this.clearInterval();
            this.toast('Auto-refresh disabled', 'Manual refresh only.', 'info');
        }
    }

    clearInterval() {
        if (this._intervalId) {
            clearInterval(this._intervalId);
            this._intervalId = undefined;
        }
    }

    handleStatusChange(e) { this.statusFilter = e.detail.value; }
    handleJobTypeChange(e) { this.jobTypeFilter = e.detail.value; }
    handleDaysBackChange(e) { this.daysBack = Number(e.detail.value); }
    handleErrorsOnlyChange(e) { this.errorsOnly = e.target.checked; }
    handleAsyncSearchChange(e) { this.asyncSearch = e.detail.value; }

    handleCronStateChange(e) { this.cronStateFilter = e.detail.value; }
    handleScheduledSearchChange(e) { this.scheduledSearch = e.detail.value; }

    handleAsyncRowAction(e) {
        const action = e.detail.action?.name;
        const row = e.detail.row;
        if (!action || !row) return;

        switch (action) {
            case 'details':
                this.openDetails(row.id);
                break;
            case 'abort':
                this.abort(row.id);
                break;
            case 'copyId':
                this.copyToClipboard(row.id);
                break;
            default:
        }
    }

    getAsyncRowActions(row, doneCallback) {
        const actions = [
            { label: 'View details', name: 'details' },
            { label: 'Copy Job Id', name: 'copyId' }
        ];

        const abortableStatuses = new Set(['Processing', 'Queued', 'Preparing', 'Holding', 'Acquired']);
        if (abortableStatuses.has(row.status)) {
            actions.push({ label: 'Abort job', name: 'abort' });
        }
        doneCallback(actions);
    }

    // --- Details / Abort ---------------------------------------------------

    async openDetails(jobId) {
        this.detailOpen = true;
        this.detail = null;
        this.detailLoading = true;

        try {
            const result = await getAsyncJobDetail({ jobId });
            this.detail = result;
        } catch (e) {
            this.toast('Detail error', this.reduceError(e), 'error');
            this.detailOpen = false;
        } finally {
            this.detailLoading = false;
        }
    }

    closeDetails() {
        this.detailOpen = false;
        this.detail = null;
    }

    handleCopyDetailId() {
        const jobId = this.detail?.job?.id;
        if (jobId) {
            this.copyToClipboard(jobId);
        }
    }

    async abort(jobId) {
        try {
            const msg = await abortJob({ jobId });
            this.toast('Abort requested', msg, 'success');
            this.refreshAll();
        } catch (e) {
            this.toast('Abort failed', this.reduceError(e), 'error');
        }
    }

    // --- Export ------------------------------------------------------------

    exportAsyncCsv() {
        const rows = this.asyncRows || [];
        if (!rows.length) {
            this.toast('Nothing to export', 'No async jobs in the current view.', 'info');
            return;
        }
        const header = ['Id','Status','JobType','ApexClass','Submitted','Completed','Processed','Total','Errors','ExtendedStatus'];
        const lines = rows.map(r => [
            r.id,
            r.status,
            r.jobType,
            r.apexClassName || '',
            this.formatIso(r.createdDate),
            this.formatIso(r.completedDate),
            r.jobItemsProcessed ?? '',
            r.totalJobItems ?? '',
            r.numberOfErrors ?? 0,
            (r.extendedStatus || '').replace(/\s+/g, ' ').trim()
        ]);
        this.downloadCsv('async-jobs.csv', header, lines);
    }

    exportScheduledCsv() {
        const rows = this.scheduledRows || [];
        if (!rows.length) {
            this.toast('Nothing to export', 'No scheduled jobs in the current view.', 'info');
            return;
        }
        const header = ['Id','Name','State','JobType','NextFire','PreviousFire','TimesTriggered','CronExpression'];
        const lines = rows.map(r => [
            r.id,
            r.name || '',
            r.state || '',
            r.jobType || '',
            this.formatIso(r.nextFireTime),
            this.formatIso(r.previousFireTime),
            r.timesTriggered ?? 0,
            r.cronExpression || ''
        ]);
        this.downloadCsv('scheduled-jobs.csv', header, lines);
    }

    downloadCsv(filename, header, rows) {
        const escape = (v) => {
            const s = (v === null || v === undefined) ? '' : String(v);
            const needsQuotes = /[",\n]/.test(s);
            const clean = s.replace(/"/g, '""');
            return needsQuotes ? `"${clean}"` : clean;
        };

        const csv = [
            header.map(escape).join(','),
            ...rows.map(r => r.map(escape).join(','))
        ].join('\n');

        const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        a.click();
        URL.revokeObjectURL(url);
    }

    // --- Refresh -----------------------------------------------------------

    refreshAll(showToast = true) {
        const promises = [];
        if (this.wiredAccess) promises.push(refreshApex(this.wiredAccess));
        if (this.wiredSummary) promises.push(refreshApex(this.wiredSummary));
        if (this.wiredAsync) promises.push(refreshApex(this.wiredAsync));
        if (this.wiredScheduled) promises.push(refreshApex(this.wiredScheduled));

        Promise.allSettled(promises).then(() => {
            if (showToast) {
                this.toast('Refreshed', 'Latest data loaded.', 'success');
            }
        });
    }

    // --- Decorators / formatting -------------------------------------------

    decorateSummary(s) {
        const byStatusPairs = this.mapToSortedPairs(s.byStatus);
        const byTypePairs = this.mapToSortedPairs(s.byType);
        return { ...s, byStatusPairs, byTypePairs };
    }

    decorateAsyncRows(rows) {
        return (rows || []).map(r => {
            const statusClass = this.statusToClass(r.status);
            const errorClass = (r.numberOfErrors && r.numberOfErrors > 0) ? 'cell-error' : '';
            const progress = this.formatProgress(r.jobItemsProcessed, r.totalJobItems);
            return { ...r, statusClass, errorClass, progress };
        });
    }

    mapToSortedPairs(mapObj) {
        if (!mapObj) return [];
        return Object.keys(mapObj)
            .map(k => ({ key: k, value: mapObj[k] }))
            .sort((a, b) => (b.value || 0) - (a.value || 0))
            .slice(0, 8);
    }

    statusToClass(status) {
        switch (status) {
            case 'Failed': return 'cell-status cell-status--failed';
            case 'Aborted': return 'cell-status cell-status--aborted';
            case 'Processing': return 'cell-status cell-status--processing';
            case 'Queued': return 'cell-status cell-status--queued';
            case 'Completed': return 'cell-status cell-status--completed';
            default: return 'cell-status';
        }
    }

    formatProgress(processed, total) {
        const p = processed ?? 0;
        const t = total ?? 0;
        if (!t) return p ? String(p) : '';
        return `${p}/${t}`;
    }

    formatIso(dt) {
        if (!dt) return '';
        try {
            return new Date(dt).toISOString();
        } catch (e) {
            return String(dt);
        }
    }

    // --- Utilities ---------------------------------------------------------

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (!error) return 'Unknown error';
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        if (typeof error.body?.message === 'string') {
            return error.body.message;
        }
        if (typeof error.message === 'string') {
            return error.message;
        }
        return JSON.stringify(error);
    }

    async copyToClipboard(text) {
        try {
            await navigator.clipboard.writeText(text);
            this.toast('Copied', 'Copied to clipboard.', 'success');
        } catch (e) {
            this.toast('Copy failed', 'Clipboard access not available in this context.', 'warning');
        }
    }
}
