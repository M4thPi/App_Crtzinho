# 🤖 Projeto CRTzinho V4.1

O **CRTzinho** é um robô móvel inteligente projetado para operações versáteis, integrando telemetria em tempo real, sistemas de segurança ativa e controle mobile através da tecnologia Bluetooth Low Energy (BLE).

---

## 🚀 Funcionalidades Principais

* **🕹️ Pilotagem Mobile:** Controle direcional intuitivo via Joystick analógico e ajuste preciso de potência (PWM).
* **🏗️ Manipulador Mecânico:** Garra frontal controlada por servo-motor para operações de "pegar e soltar" objetos.
* **📊 Telemetria em Tempo Real:** Monitoramento contínuo de temperatura ambiente (DHT11) e nível de carga das baterias diretamente no app.
* **⚠️ Segurança Ativa (Anti-Colisão):** Sistema de frenagem e interrupção automática de movimento ao detectar obstáculos via sensor ultrassônico.
* **📟 Feedback Visual:** Display LCD nativo para exibição de status do sistema e mensagens de texto personalizadas enviadas pelo App.
* **🧠 Processamento Dual-Core:** Uso de FreeRTOS para dividir o gerenciamento de rede/sensores (Core 0) de motores e garra (Core 1), garantindo resposta imediata sem travamentos.

---

## 🛠️ Arquitetura de Hardware

O projeto utiliza uma malha de energia robusta, separando as correntes de potência e controle para evitar ruídos e quedas de tensão (brownouts) no cérebro do sistema.

| Componente | Função no Sistema |
| :--- | :--- |
| **ESP32** | Cérebro principal com processamento Dual-Core e comunicação BLE. |
| **L298N** | Ponte H (Driver de potência) para o acionamento dos motores de tração. |
| **L7805CV** | Regulador de tensão linear (5V) dedicado para proteger o ESP32 e o Servo. |
| **HC-SR04** | Sensor ultrassônico utilizado como "radar" para prevenção de colisões. |
| **DHT11** | Sensor responsável pela telemetria de temperatura e umidade. |
| **LCD 16x2** | Interface de saída visual em modo I2C/4-bits. |
| **Servo SG90** | Atuador mecânico de precisão para a garra. |

---

## 💻 Estrutura de Software

### Firmware (C++ / FreeRTOS)
A programação embarcada utiliza a arquitetura do FreeRTOS para paralelismo de tarefas e baixíssima latência:
* **Core 0:** Gerenciamento do servidor Bluetooth (BLE) e leitura constante de sensores críticos.
* **Core 1:** Controle em malha fechada dos motores de tração e suavização mecânica do servo-motor.

### Mobile App (Flutter / Dart)
Aplicativo desenvolvido com o framework Flutter, focado em uma interface limpa e reativa:
* Utilização da biblioteca `flutter_blue_plus` para comunicação de baixa latência.
* Envio de comandos mecânicos instantâneos via pacotes de bytes (Characteristic Write).
* Recebimento de dados de telemetria via notificações contínuas (Characteristic Notify).

---

## 🔧 Configuração e Instalação

### Preparando o Robô (Firmware)
1. Instale o pacote de placas **ESP32** na sua Arduino IDE.
2. Gerencie as bibliotecas e instale: `ESP32Servo`, `DHT sensor library` e `LiquidCrystal_I2C`.
3. Carregue o código do arquivo fonte para a placa ESP32.

### Preparando o Aplicativo (Mobile)
1. Certifique-se de ter o [Flutter](https://docs.flutter.dev/get-started/install) devidamente instalado.
2. No terminal, acesse a pasta raiz do aplicativo e execute:
   ```bash
   flutter pub get
Atenção Android: Confirme se as permissões de Bluetooth (BLUETOOTH_SCAN, BLUETOOTH_CONNECT) e Localização estão configuradas no AndroidManifest.xml.

Execute o App:

Bash
 "flutter run"

🧠 Nota de Engenharia
A migração do Bluetooth Clássico para o BLE (Bluetooth Low Energy) nesta versão permitiu uma autonomia de bateria significativamente maior, além de viabilizar a compatibilidade nativa cross-platform (Android e iOS), elevando o CRTzinho ao estado da arte em prototipagem IoT educacional.

👤 Desenvolvedor

Este projeto foi desenvolvido por:

Misael

📝 Licença
Este projeto foi construído com foco em pesquisa tecnológica e é distribuído para fins educacionais.
