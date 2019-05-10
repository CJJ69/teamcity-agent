ARG TAG=ltsc2019
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-$TAG AS tools

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]


# Install JDK
RUN [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls' ; \
    Invoke-WebRequest https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u192-b12/OpenJDK8U-jdk_x64_windows_hotspot_8u192b12.zip -OutFile jdk.zip; \
    Expand-Archive jdk.zip -DestinationPath $Env:ProgramFiles\Java ; \
    Get-ChildItem $Env:ProgramFiles\Java | Rename-Item -NewName "OpenJDK" ; \
    Remove-Item $Env:ProgramFiles\Java\OpenJDK\demo -Force -Recurse ; \
    Remove-Item $Env:ProgramFiles\Java\OpenJDK\sample -Force -Recurse ; \
    Remove-Item $Env:ProgramFiles\Java\OpenJDK\src.zip -Force ; \
    Remove-Item -Force jdk.zip

# Install Git
RUN [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls' ; \
    Invoke-WebRequest https://github.com/git-for-windows/git/releases/download/v2.21.0.windows.1/MinGit-2.21.0-64-bit.zip -OutFile git.zip; \
    Expand-Archive git.zip -DestinationPath $Env:ProgramFiles\Git ; \
    Remove-Item -Force git.zip

# Install Mercurial
RUN [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls' ; \
    Invoke-WebRequest https://bitbucket.org/tortoisehg/files/downloads/mercurial-4.7.2-x64.msi -OutFile hg.msi; \
    Start-Process msiexec -Wait -ArgumentList /q, /i, hg.msi ; \
    Remove-Item -Force hg.msi

# get latest version of Nuget
ENV NUGET_VERSION v4.9.4
#ENV NUGET_VERSION latest
RUN Invoke-WebRequest -UseBasicParsing https://dist.nuget.org/win-x86-commandline/$Env:NUGET_VERSION/nuget.exe -OutFile $Env:ProgramFiles/NuGet/nuget.exe;

# Install Sleet
RUN [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls' ; \
    Invoke-WebRequest https://www.nuget.org/api/v2/package/Sleet/2.3.79 -OutFile sleet.zip; \
    Expand-Archive sleet.zip -DestinationPath $Env:ProgramFiles/Sleet ; \
    Remove-Item -Force sleet.zip

# Sleet create json config
RUN Start-Process Sleet.exe -WorkingDirectory $Env:ProgramFiles/Sleet/tools  \
        -ArgumentList 'createconfig', '--azure' \
        -NoNewWindow -Wait;


#FROM teamcity-minimal-agent:latest AS buildagent
FROM jetbrains/teamcity-minimal-agent AS buildagent

FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-$TAG

COPY --from=tools ["C:/Program Files/Java/OpenJDK", "C:/Program Files/Java/OpenJDK"]
COPY --from=tools ["C:/Program Files/Git", "C:/Program Files/Git"]
COPY --from=tools ["C:/Program Files/Mercurial", "C:/Program Files/Mercurial"]
COPY --from=tools ["C:/Program Files/NuGet", "C:/Program Files/NuGet"]
COPY --from=tools ["C:/Program Files/Sleet", "C:/Program Files/Sleet"]
COPY --from=buildagent /BuildAgent /BuildAgent

COPY Scripts/*.* /Scripts/

# Install Chocolatey, VS Data SSDT, Web Build Tools
RUN [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls' ; \
    Invoke-WebRequest -UseBasicParsing https://chocolatey.org/install.ps1 | Invoke-Expression; \
    Invoke-WebRequest -UseBasicParsing https://download.visualstudio.microsoft.com/download/pr/bea50589-003e-423f-b887-9bf2d70e998c/acfe10c084a64949c1fff4d864ed9b35/vs_buildtools.exe -OutFile vs_BuildTools.exe; \
    # Installer won't detect DOTNET_SKIP_FIRST_TIME_EXPERIENCE if ENV is used, must use setx /M
    setx /M DOTNET_SKIP_FIRST_TIME_EXPERIENCE 1; \
    Start-Process vs_BuildTools.exe \
        -ArgumentList \
            '--add', 'Microsoft.VisualStudio.Workload.DataBuildTools', \
            '--add', 'Microsoft.VisualStudio.Workload.WebBuildTools', \
            '--quiet', '--norestart', '--nocache', '--includeRecommended' \
        -NoNewWindow -Wait; \
    Remove-Item -Force vs_buildtools.exe; \
    Remove-Item -Force -Recurse 'C:/Program Files (x86)/Microsoft Visual Studio/Installer'; \
    Remove-Item -Force -Recurse $Env:TEMP\*;

# Install Yarn and NodeJs dependency
RUN Invoke-Expression 'choco install yarn -y';

# Install Docker client
RUN Invoke-Expression 'choco install docker-cli -y';

EXPOSE 9090

VOLUME C:/BuildAgent/conf

ENTRYPOINT ["/Scripts/entrypoint.bat"]
# moved to Entrypoint.bat
#CMD ./BuildAgent/run-agent.ps1

    # Configuration file for TeamCity agent
ENV CONFIG_FILE="C:/BuildAgent/conf/buildAgent.properties" \
    # Java home directory
    JAVA_HOME="C:\Program Files\Java\OpenJDK" \
    # Opt out of the telemetry feature
    DOTNET_CLI_TELEMETRY_OPTOUT=true \
    # Disable first time experience
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true \
    # Configure Kestrel web server to bind to port 80 when present
    ASPNETCORE_URLS=http://+:80 \
    # Enable detection of running in a container
    DOTNET_RUNNING_IN_CONTAINER=true \
    # Enable correct mode for dotnet watch (only mode supported in a container)
    DOTNET_USE_POLLING_FILE_WATCHER=true \
    # Skip extraction of XML docs - generally not useful within an image/container - helps perfomance
    NUGET_XMLDOC_MODE=skip \
    # Connection String for Nuget feed must be specified when instantiating container
    FEED_CONN_STR=""

# add hosts file entry for old TFS source repo
RUN Add-Content "C:/Windows/System32/drivers/etc/hosts" "`n192.168.10.201`twhdev"

RUN setx /M PATH ('{0};{1}\bin;C:\Program Files\Git\cmd;C:\Program Files\Sleet\tools;C:\Program Files\Mercurial' -f $env:PATH, $env:JAVA_HOME)
