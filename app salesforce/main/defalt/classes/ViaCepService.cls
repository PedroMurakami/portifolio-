public with sharing class ViaCepService {
    
    @future(callout=true)
    public static void atualizarEnderecoEvento(Set<Id> eventoIds) {
        List<Evento__c> eventosParaAtualizar = new List<Evento__c>();
        
        List<Evento__c> eventos = [SELECT Id, CEP__c FROM Evento__c WHERE Id IN :eventoIds];
        
        for (Evento__c evt : eventos) {
            if (String.isNotBlank(evt.CEP__c)) {
                // Remove caracteres especiais do CEP
                String cepLimpo = evt.CEP__c.replaceAll('[^0-9]', '');
                
                Http http = new Http();
                HttpRequest request = new HttpRequest();
                request.setEndpoint('https://viacep.com.br/ws/' + cepLimpo + '/json/');
                request.setMethod('GET');
                request.setTimeout(120000);
                
                try {
                    HttpResponse response = http.send(request);
                    
                    if (response.getStatusCode() == 200) {
                        Map<String, Object> resultado = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                        
                        if (resultado.get('erro') == null) {
                            evt.Logradouro__c = (String) resultado.get('logradouro');
                            evt.Cidade__c = (String) resultado.get('localidade');
                            evt.Estado__c = (String) resultado.get('uf');
                            eventosParaAtualizar.add(evt);
                        }
                    }
                } catch (Exception e) {
                    System.debug('Erro ao integrar com ViaCEP: ' + e.getMessage());
                }
            }
        }
        
        if (!eventosParaAtualizar.isEmpty()) {
            update eventosParaAtualizar;
        }
    }
}