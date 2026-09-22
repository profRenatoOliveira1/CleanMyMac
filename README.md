# 🧹 macOS System Cleaner
Uma ferramenta nativa, leve e eficiente desenvolvida em Swift para otimização e limpeza de arquivos desnecessários no macOS.

---

## 📋 Sobre o Projeto
Com o tempo de uso, o macOS acumula uma grande quantidade de arquivos temporários, logs de sistema, caches de aplicativos e dados residuais (como contêineres e imagens não utilizadas do Docker). 
Este aplicativo foi desenvolvido para identificar e remover com segurança esses arquivos dispensáveis, liberando espaço em disco e mantendo o desempenho do sistema sem comprometer o funcionamento do sistema operacional.

---

## ✨ Funcionalidades Planejadas / Principais Recursos

- [ ] **Limpeza de Caches:** Remoção de arquivos de cache do sistema e de usuários (`~/Library/Caches`).
- [ ] **Logs do Sistema:** Limpeza de arquivos de log antigos (`~/Library/Logs`).
- [ ] **Lixo do Docker:** Remoção de contêineres parados, imagens "dangling", volumes não utilizados e cache de build.
- [ ] **Arquivos Temporários:** Identificação e exclusão de dados temporários de aplicações.
- [ ] **Esvaziamento da Lixeira:** Limpeza segura do lixo do sistema.
- [ ] **Interface Amigável:** Dashboard nativo construído para visualização de espaço recuperável.

---

## 🛠️ Tecnologias Utilizadas

O projeto é desenvolvido 100% de forma nativa para o ecossistema Apple:

- **Linguagem:** [Swift](https://swift.org/)
- **Interface:** [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- **Ferramentas:** Xcode / Foundation / System Frameworks

---

## ⚠️ Isenção de Responsabilidade (Disclaimer)

> **Atenção:** Este software manipula a exclusão de arquivos no sistema de arquivos local. Embora o aplicativo tenha sido projetado para remover apenas dados seguros e não essenciais, **use-o por sua própria conta e risco**. Recomenda-se manter um backup recente (via Time Machine ou similar) antes de executar varreduras e limpezas profundas.

---

## 🚀 Como Executar o Projeto Localmente

### Pré-requisitos
- macOS rodando a versão 13.0 (Ventura) ou superior.
- Xcode 15.0+ instalado.

### Passos
1. Clone o repositório:
   ```bash
   git clone https://github.com/seu-usuario/seu-repositorio.git
   ```
2. Abra o projeto no Xcode:
   ```bash
   cd seu-repositorio
   open CleanMyMac.xcodeproj
   ```
3. Compile e execute o projeto pressionando `Cmd + R` no Xcode.

---

## 🤝 Como Contribuir

Contribuições são super bem-vindas! Se você deseja adicionar uma nova regra de limpeza, corrigir um bug ou melhorar a interface:

1. Faça um **Fork** do projeto.
2. Crie uma Branch para sua funcionalidade (`git checkout -b feature/NovaFuncionalidade`).
3. Faça o **Commit** de suas alterações (`git commit -m 'Adiciona funcionalidade X'`).
4. Envie a Branch para o repositório (`git push origin feature/NovaFuncionalidade`).
5. Abra um **Pull Request**.

---

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.
