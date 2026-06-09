import { LightningElement } from 'lwc';

export default class LightningModal extends LightningElement {
    static open() {
        return Promise.resolve();
    }
    close() {
        return Promise.resolve();
    }
}
