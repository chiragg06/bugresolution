import { LightningElement, api } from 'lwc';

export default class CaseListPaginator extends LightningElement {
  @api pageNumber = 1;
  @api totalPages = 1;

  get isFirst() { return this.pageNumber <= 1; }
  get isLast()  { return this.pageNumber >= this.totalPages; }

  goFirst = () => this.fire('first');
  goPrev  = () => this.fire('prev');
  goNext  = () => this.fire('next');
  goLast  = () => this.fire('last');

  fire(detail) { this.dispatchEvent(new CustomEvent('nav', { detail })); }
}
