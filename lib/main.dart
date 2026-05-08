import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CrtzinhoApp());
}

// ==========================================
// VARIÁVEIS GLOBAIS (Arquitetura BLE)
// ==========================================
BluetoothDevice? connectedDevice;
BluetoothCharacteristic? txCharacteristic; // ESP32 -> App (Lê Sensores)
BluetoothCharacteristic? rxCharacteristic; // App -> ESP32 (Envia Comandos)

StreamController<String> streamDados = StreamController<String>.broadcast();
DateTime _ultimoEnvio = DateTime.now();

// UUIDs idênticos aos que estão no código C++ do ESP32
const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const String RX_CHAR_UUID =
    "beb5483e-36e1-4688-b7f5-ea07361b26a8"; // App Escreve
const String TX_CHAR_UUID = "75c276c3-8f97-20bc-a143-b354244886d4"; // App Lê

// ==========================================
// FUNÇÕES GLOBAIS
// ==========================================
void desconectarGlobal(BuildContext context) async {
  if (connectedDevice != null) {
    await connectedDevice!.disconnect();
  }
  connectedDevice = null;
  txCharacteristic = null;
  rxCharacteristic = null;

  // Força o app a voltar para a tela inicial
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('❌ Conexão BLE encerrada.'),
      backgroundColor: Colors.redAccent,
    ),
  );
}

void enviarComando(String comando) async {
  if (rxCharacteristic == null) {
    print("🚨 ERRO: App não achou a 'boca' do ESP32 (Característica RX nula)!");
    return;
  }

  // Proteção contra engarrafamento do Bluetooth
  if (comando.startsWith("JOY:")) {
    // Identifica se o usuário soltou o dedo (voltou para o centro 0,0)
    bool isParando = comando == "JOY:0.00,0.00" || comando == "JOY:0.0,0.0";

    // Se NÃO for comando de parada, e tiver passado menos de 50ms, bloqueia
    if (!isParando &&
        DateTime.now().difference(_ultimoEnvio).inMilliseconds < 50) {
      return;
    }
    _ultimoEnvio = DateTime.now();
  }

  try {
    print("Enviando via BLE: $comando");
    await rxCharacteristic!.write(utf8.encode(comando), withoutResponse: true);
  } catch (e) {
    print("🚨 Erro na antena Bluetooth: $e");
  }
}

// ==========================================
// APLICATIVO PRINCIPAL
// ==========================================
class CrtzinhoApp extends StatelessWidget {
  const CrtzinhoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crtzinho',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurpleAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          centerTitle: true,
          elevation: 0,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const TelaApresentacao(),
        '/conexao': (context) => const TelaConexao(),
        '/painel': (context) => const TelaPainel(),
      },
    );
  }
}

// ==========================================
// 1. TELA DE APRESENTAÇÃO
// ==========================================
class TelaApresentacao extends StatefulWidget {
  const TelaApresentacao({Key? key}) : super(key: key);

  @override
  State<TelaApresentacao> createState() => _TelaApresentacaoState();
}

class _TelaApresentacaoState extends State<TelaApresentacao> {
  bool _permissoesConcedidas = false;

  @override
  void initState() {
    super.initState();
    _solicitarPermissoes(); // Chama as permissões ao iniciar
  }

  // Função para pedir permissões de Bluetooth e Localização (obrigatório para BLE)
  Future<void> _solicitarPermissoes() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothConnect]!.isGranted &&
        statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.location]!.isGranted) {
      setState(() {
        _permissoesConcedidas = true;
      });
    } else {
      // Libera mesmo assim para testes (o ideal seria travar se o usuário recusar)
      setState(() {
        _permissoesConcedidas = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.blueAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 60.0,
            ),
            child: Column(
              children: [
                const Text(
                  'Crtzinho',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 30),

                // IMAGEM CENTRALIZADA
                Center(
                  child: SizedBox(
                    width: 250,
                    child: _buildMolduraFoto(
                      'assets/images/logo.jpg',
                      'O Robô',
                    ),
                  ),
                ),

                const SizedBox(height: 30),
                const Text(
                  'Nossa História',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Este projeto foi desenvolvido pelos estagiários Vivian, Misael, Andrey, Ana Bárbara e Breno com o objetivo de criar um robô versátil e inteligente. '
                  'A atualização do CRTzinho modernizou a estrutura física e trouxe esta interface mobile.\n\n'
                  'Focamos em criar uma experiência intuitiva para monitorar sensores e controlar movimentos em tempo real.',
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                // BOTÃO INICIAR SISTEMA
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 15,
                    ),
                  ),
                  onPressed: _permissoesConcedidas
                      ? () => Navigator.pushNamed(context, '/conexao')
                      : null,
                  child: Text(
                    _permissoesConcedidas ? 'INICIAR SISTEMA' : 'PERMISSÕES...',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Função para criar a moldura da foto
  Widget _buildMolduraFoto(String caminho, String legenda) {
    return Column(
      children: [
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.asset(
              caminho,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.smart_toy, size: 80, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          legenda,
          style: const TextStyle(
            color: Colors.white70,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 2. TELA DE CONEXÃO (Lógica BLE Escaneando o Ar)
// ==========================================
class TelaConexao extends StatefulWidget {
  const TelaConexao({Key? key}) : super(key: key);
  @override
  _TelaConexaoState createState() => _TelaConexaoState();
}

class _TelaConexaoState extends State<TelaConexao> {
  bool isConnecting = false;
  String statusText = "Pronto para buscar o robô";
  StreamSubscription? _scanSubscription;

  void conectarBLE() async {
    setState(() {
      isConnecting = true;
      statusText = "Verificando Bluetooth...";
    });

    // 1. TENTA LIGAR O BLUETOOTH AUTOMATICAMENTE SE ESTIVER DESLIGADO
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      setState(() => statusText = "Tentando ligar o Bluetooth...");
      try {
        // Tenta forçar a ativação do Bluetooth (Android)
        await FlutterBluePlus.turnOn();
        // Espera um tempinho para o adaptador ligar de fato
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        setState(() {
          isConnecting = false;
          statusText = "Ligue o Bluetooth manualmente!";
        });
        return; // Para a execução aqui se o usuário recusar ou der erro
      }
    }

    setState(() => statusText = "Procurando no ar...");

    // 2. Inicia o escaneamento SEM FILTRO para ver todos os dispositivos
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    // 3. Escuta os resultados
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        // LOG PARA VER NO CONSOLE TUDO QUE ELE ACHA
        print("Encontrei: ${r.device.platformName} ID: ${r.device.remoteId}");

        // Se o nome for o nosso robô
        if (r.device.platformName == "ESP32_CRTzinho") {
          // Para de escanear o ar
          await FlutterBluePlus.stopScan();

          setState(() => statusText = "Robô encontrado! Conectando...");

          try {
            // 4. Conecta ao dispositivo BLE
            await r.device.connect();
            connectedDevice = r.device;

            // 5. Escuta caso o robô desligue ou fique fora de área
            connectedDevice!.connectionState.listen((
              BluetoothConnectionState state,
            ) {
              if (state == BluetoothConnectionState.disconnected && mounted) {
                desconectarGlobal(context);
              }
            });

            setState(() => statusText = "Descobrindo serviços...");

            // 6. Descobre os Serviços e Características
            List<BluetoothService> services = await r.device.discoverServices();
            for (BluetoothService service in services) {
              String sId = service.uuid.toString().toLowerCase();

              if (sId.contains(SERVICE_UUID.toLowerCase())) {
                for (BluetoothCharacteristic c in service.characteristics) {
                  String cId = c.uuid.toString().toLowerCase();

                  // Encontra a característica de ESCRITA (Para enviar Joystick/Velocidade)
                  if (cId.contains(RX_CHAR_UUID.toLowerCase())) {
                    rxCharacteristic = c;
                    print("✅ ALVO TRAVADO: Característica RX encontrada!");
                  }

                  // Encontra a característica de LEITURA (Para ler Temperatura/Bateria)
                  if (cId.contains(TX_CHAR_UUID.toLowerCase())) {
                    txCharacteristic = c;
                    print("✅ SENSOR TRAVADO: Característica TX encontrada!");

                    // Avisa o ESP32 que queremos receber os dados
                    await txCharacteristic!.setNotifyValue(true);

                    // Escuta os dados chegando e joga no Stream global
                    txCharacteristic!.onValueReceived.listen((value) {
                      String mensagemRecebida = utf8.decode(value);
                      streamDados.add(mensagemRecebida);
                    });
                  }
                }
              }
            }

            // Se chegou até aqui, está tudo certo! Vai para o painel.
            setState(() => isConnecting = false);
            if (mounted) Navigator.pushReplacementNamed(context, '/painel');
          } catch (e) {
            setState(() {
              isConnecting = false;
              statusText = "Falha ao conectar.";
            });
            print("Erro de conexão BLE: $e");
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conexão BLE')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bluetooth_searching,
              size: 80,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 20),
            Text(
              statusText,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 30),
            isConnecting
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    icon: const Icon(Icons.bluetooth),
                    label: const Text('BUSCAR ROBÔ'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                    onPressed: conectarBLE,
                  ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. TELA DE PAINEL (STATUS)
// ==========================================
class TelaPainel extends StatefulWidget {
  const TelaPainel({Key? key}) : super(key: key);
  @override
  _TelaPainelState createState() => _TelaPainelState();
}

class _TelaPainelState extends State<TelaPainel> {
  String temperatura = "--";
  String bateria = "--";
  StreamSubscription? _sensorSubscription;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Escuta os dados que vêm do ESP32 via BLE
    _sensorSubscription = streamDados.stream.listen((linha) {
      if (linha.startsWith("DHT:")) {
        List<String> partes = linha.substring(4).split(',');
        if (partes.length == 2) {
          setState(() {
            temperatura = partes[0];
            bateria = partes[1];
          });
        }
      } else if (linha.contains("ALERTA: OBSTACULO")) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ ALERTA: Obstáculo Detectado à frente!'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status do Robô'),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.red),
            tooltip: "Desconectar",
            onPressed: () => desconectarGlobal(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildCard(
              "Temperatura",
              "$temperatura °C",
              Icons.thermostat,
              Colors.redAccent,
            ),
            const SizedBox(height: 15),
            _buildCard(
              "Bateria",
              "$bateria %",
              Icons.battery_charging_full,
              Colors.greenAccent,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.gamepad),
                label: const Text('PILOTAR ROBÔ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TelaPilotagem(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.monitor),
                label: const Text('MENSAGEM LCD'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TelaDisplay()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String titulo, String valor, IconData icone, Color cor) {
    return Card(
      color: const Color(0xFF1E1E2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icone, color: cor, size: 40),
        title: Text(titulo),
        trailing: Text(
          valor,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ==========================================
// 4. TELA DE PILOTAGEM (HORIZONTAL)
// ==========================================
class TelaPilotagem extends StatefulWidget {
  const TelaPilotagem({Key? key}) : super(key: key);
  @override
  _TelaPilotagemState createState() => _TelaPilotagemState();
}

class _TelaPilotagemState extends State<TelaPilotagem> {
  bool garraFechada = false;
  double velocidade = 85.0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Manda a velocidade inicial do slider (85) para o robô assim que a tela abre
    // O Future.delayed garante que a tela terminou de carregar antes de enviar
    Future.delayed(const Duration(milliseconds: 500), () {
      enviarComando("VEL:${velocidade.round()}");
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    enviarComando("JOY:0.0,0.0"); // Para o robô ao sair da tela
    super.dispose();
  }

  // Função auxiliar para criar os botões direcionais
  Widget _buildBotaoDirecional(IconData icone, String comandoAcao) {
    return GestureDetector(
      onTapDown: (_) => enviarComando(comandoAcao), // Envia movimento
      onTapUp: (_) => enviarComando("JOY:0.0,0.0"), // Para ao soltar
      onTapCancel: () =>
          enviarComando("JOY:0.0,0.0"), // Para se o dedo deslizar fora
      child: Container(
        margin: const EdgeInsets.all(8),
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          color: Colors.blueAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 5,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Icon(icone, size: 40, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Controle Mecânico'), toolbarHeight: 40),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. D-PAD DIREACIONAL (Botões)
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBotaoDirecional(
                Icons.keyboard_arrow_up,
                "JOY:0.0,-1.0",
              ), // FRENTE
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildBotaoDirecional(
                    Icons.keyboard_arrow_left,
                    "JOY:-1.0,0.0",
                  ), // ESQUERDA
                  const SizedBox(width: 65), // Espaço vazio no meio
                  _buildBotaoDirecional(
                    Icons.keyboard_arrow_right,
                    "JOY:1.0,0.0",
                  ), // DIREITA
                ],
              ),
              _buildBotaoDirecional(
                Icons.keyboard_arrow_down,
                "JOY:0.0,1.0",
              ), // TRÁS
            ],
          ),

          // 2. CONTROLE DE VELOCIDADE
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'POTÊNCIA',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: velocidade,
                min: 0,
                max: 100,
                activeColor: Colors.deepPurpleAccent,
                onChanged: (v) => setState(() => velocidade = v),
                onChangeEnd: (v) => enviarComando("VEL:${v.round()}"),
              ),
              Text('${velocidade.round()}%'),
            ],
          ),

          // 3. CONTROLE DA GARRA (CORRIGIDO)
          GestureDetector(
            onTap: () {
              setState(() => garraFechada = !garraFechada);
              // Agora envia exatamente o que o C++ espera!
              enviarComando(garraFechada ? "GARRA_FECHAR" : "GARRA_ABRIR");
            },
            child: CircleAvatar(
              radius: 45,
              backgroundColor: garraFechada ? Colors.redAccent : Colors.green,
              child: Text(
                garraFechada ? "SOLTAR" : "PEGAR",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. TELA DE DISPLAY
// ==========================================
class TelaDisplay extends StatelessWidget {
  const TelaDisplay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController _controller = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Visor LCD Nativo')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.tv, size: 60, color: Colors.white54),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              maxLength:
                  32, // Limitado a 16 pois a linha 2 do seu LCD só cabe isso
              decoration: const InputDecoration(
                labelText: 'Mensagem para a linha 2',
                filled: true,
                fillColor: Color(0xFF1E1E2C),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('ENVIAR MENSAGEM'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
              ),
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  enviarComando("TXT:${_controller.text}");
                  _controller.clear();
                  FocusScope.of(
                    context,
                  ).unfocus(); // Fecha o teclado após enviar

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Mensagem enviada para o LCD!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
