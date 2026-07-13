import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getEventosAtivos from '@salesforce/apex/EventoController.getEventosAtivos';
import criarIngresso from '@salesforce/apex/EventoController.criarIngresso';

export default class VendaIngressoRapida extends LightningElement {
    @track eventoSelecionado = '';
    @track nome = '';
    @track email = '';
    @track opcoesEventos = [];

    @wire(getEventosAtivos)
    wiredEventos({ error, data }) {
        if (data) {
            this.opcoesEventos = data.map(evt => {
                return { label: evt.Name, value: evt.Id };
            });
        } else if (error) {
            this.showToast('Erro', 'Erro ao carregar eventos', 'error');
        }
    }

    handleEventoChange(event) {
        this.eventoSelecionado = event.detail.value;
    }

    handleNomeChange(event) {
        this.nome = event.target.value;
    }

    handleEmailChange(event) {
        this.email = event.target.value;
    }

    get isBotaoDesabilitado() {
        return !this.eventoSelecionado || !this.nome || !this.email;
    }

    handleSalvar() {
        criarIngresso({ 
            eventoId: this.eventoSelecionado, 
            nomeParticipante: this.nome, 
            emailParticipante: this.email 
        })
        .then(() => {
            this.showToast('Sucesso', 'Ingresso emitido e confirmado com sucesso!', 'success');
            this.limparFormulario();
        })
        .catch(error => {
            this.showToast('Erro', error.body.message, 'error');
        });
    }

    limparFormulario() {
        this.eventoSelecionado = '';
        this.nome = '';
        this.email = '';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}