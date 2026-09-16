flowchart LR
    P["👤 Pasajero"]
    A["👤 Agente de reservas<br/>Personal de la aerolínea"]
    
    S["AeroReserva<br/><br/>Sistema web para consultar vuelos,<br/>registrar pasajeros y gestionar reservas."]
    
    P -->|"Consulta vuelos, registra sus datos,<br/>crea y cancela sus reservas"| S
    
    A -->|"Consulta reservas y gestiona<br/>reservas o cancelaciones solicitadas"| S