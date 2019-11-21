# AVAPolos 0.2
Repositório da solução AVAPolos versão 0.2

##Instalação
Para instalar a solução, basta executar os seguintes comandos:

`git clone https://github.com/C3FURG/AVAPolos avapolos`

`cd avapolos/build && bash compilar.sh`
O script compilar.sh permite que sejam escolhidos templates de instalação.
1) Intalação completa - contém todos os serviços do AVAPolos.
2) Instalação mínima - contém Página inicial, Painel de controle, Portainer. 
3) Moodle_dev - contém Página inicial, Painel de controle, Portainer e Moodle.
5) sem_educapes - contém Página inicial, Painel de controle, Portainer, Moodle e Wiki.

Se a reinicialização da máquina for requisitada, reinicie e execute os seguintes comandos num terminal.

`cd avapolos/build && bash compilar.sh`

Após o término da compilação, instale a solução com o seguinte comando.

`sudo ·/NOMEDOINSTALADOR`

##Clonagem
Para clonar um servidor IES, basta executar os seguintes comandos:

`sudo avapolos --export-all`

Para instalá-lo:

`sudo ./NOMEDOINSTALADOR-CLONE`
