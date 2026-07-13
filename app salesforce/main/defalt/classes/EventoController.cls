public with sharing class EventoController {
    
    @AuraEnabled(cacheable=true)
    public static List<Evento__c> getEventosAtivos() {
        return [SELECT Id, Name FROM Evento__c ORDER BY Name ASC];
    }
    
    @AuraEnabled
    public static String criarIngresso(Id eventoId, String nomeParticipante, String emailParticipante) {
        try {
            Ingresso__c novoIngresso = new Ingresso__c();
            novoIngresso.Evento__c = eventoId;
            novoIngresso.Nome_Participante__c = nomeParticipante;
            novoIngresso.Email_Participante__c = emailParticipante;
            novoIngresso.Status__c = 'Confirmado';
            
            insert novoIngresso;
            return novoIngresso.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Erro ao emitir ingresso: ' + e.getMessage());
        }
    }
}