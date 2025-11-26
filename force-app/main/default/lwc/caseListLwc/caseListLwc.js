import { LightningElement, track } from 'lwc';
import searchCases from '@salesforce/apex/CaseListController.searchCases';

export default class CaseListLwc extends LightningElement {
  @track searchText = '';
  @track pageNumber = 1;
  @track pageSize   = 25;
  @track totalPages = 1;
  @track rows       = [];
  @track toastText  = '';

  columns = [
    { label: 'Case Number', fieldName: 'CaseNumber', type: 'text' },
    { label: 'Subject',     fieldName: 'Subject',    type: 'text' },
    { label: 'Status',      fieldName: 'Status',     type: 'text' },
    { label: 'Priority',    fieldName: 'Priority',   type: 'text' },
    { label: 'Owner',       fieldName: 'OwnerName',  type: 'text' },
    { label: 'Created',     fieldName: 'CreatedDate', type: 'date' }
  ];

  connectedCallback() { this.loadPage(1); }

  async loadPage(page) {
    const pn = page < 1 ? 1 : page;
    try {
      const resp = await searchCases({ searchText: this.searchText, pageNumber: pn, pageSize: this.pageSize });
      // Normalize to avoid "records undefined" bugs on deep pages
      const list = (resp && resp.records) ? resp.records : [];
      this.rows = list.map(r => ({
        Id: r.Id,
        CaseNumber: r.CaseNumber,
        Subject: r.Subject,
        Status: r.Status,
        Priority: r.Priority,
        OwnerName: r.Owner?.Name,
        CreatedDate: r.CreatedDate
      }));
      this.pageNumber = resp?.pageNumber || pn;
      this.totalPages = resp?.totalPages || 1;
      this.toastText  = `Loaded page ${this.pageNumber} of ${this.totalPages}`;
    } catch (e) {
      // Defensive: if anything fails, ensure rows is at least an empty array
      this.rows = [];
      this.toastText = 'Error loading cases. Please try again.';
      // eslint-disable-next-line no-console
      console.error(e);
    }
  }

  onNav(evt) {
    const dir = evt.detail; // 'first' | 'prev' | 'next' | 'last'
    let target = this.pageNumber;
    if (dir === 'first') target = 1;
    if (dir === 'prev')  target = Math.max(1, this.pageNumber - 1);
    if (dir === 'next')  target = Math.min(this.totalPages, this.pageNumber + 1);
    if (dir === 'last')  target = this.totalPages;
    this.loadPage(target);
  }

  onSearchChange(e) { this.searchText = e.target.value || ''; }
  runSearch() { this.loadPage(1); }
}
