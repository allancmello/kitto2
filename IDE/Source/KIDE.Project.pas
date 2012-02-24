unit KIDE.Project;

interface

uses
  Classes,
  EF.Tree,
  Kitto.Config;

type
  TProjectConfig = class(TKConfig)
  end;

  TProject = class(TEFTree)
  private
    FFileName: string;
    FConfig: TProjectConfig;
    class var FCurrentProject: TProject;
    function GetDirectory: string;
    procedure RefreshConfig;
    class procedure SetCurrentProject(const AValue: TProject); static;
    function GetSourceDirectory: string;
    function GetMRUKeyName: string;
    class procedure ApplyProjectTemplate(const ATemplateName,
      AProjectFileName: string); static;
  public
    class property CurrentProject: TProject read FCurrentProject write SetCurrentProject;
    class destructor Destroy;

    class procedure NewProject(const AFileName: string);
    class procedure OpenProject(const AFileName: string);
    class procedure CloseProject;
    destructor Destroy; override;

    property FileName: string read FFileName;

    property Directory: string read GetDirectory;
    property SourceDirectory: string read GetSourceDirectory;

    property Config: TProjectConfig read FConfig;

    procedure GetConfigFileNames(const AFileNames: TStrings);

    // Project-scoped MRUs.
    procedure StoreString(const AKey, AValue: string);
    procedure StoreInteger(const AKey: string; const AValue: Integer);
    procedure StoreBoolean(const AKey: string; const AValue: Boolean);
    procedure StoreMRUItem(const AKey, AValue: string);
    procedure StoreStrings(const AKey: string; const AStrings: TStrings);

    procedure RetrieveStrings(const AKey: string; const AStrings: TStrings);
    function RetrieveString(const AKey: string; const ADefault: string = ''): string;
    function RetrieveBoolean(const AKey: string; const ADefault: Boolean = False): Boolean;
  end;

implementation

uses
  Windows, SysUtils,
  EF.SysUtils, EF.StrUtils, EF.YAML, EF.Macros,
  KIDE.MRUOptions;

{ TProject }

class procedure TProject.CloseProject;
begin
  FreeAndNil(FCurrentProject);
end;

destructor TProject.Destroy;
begin
  FreeAndNil(FConfig);
  inherited;
end;

class destructor TProject.Destroy;
begin
  CloseProject;
end;

procedure TProject.GetConfigFileNames(const AFileNames: TStrings);
begin
  FindAllFiles('yaml', Config.GetMetadataPath, AFileNames, False, True);
end;

function TProject.GetDirectory: string;
begin
  Result := ExtractFilePath(FileName);
end;

function TProject.GetMRUKeyName: string;
begin
  Result := EncodeYAMLKey(FileName);
end;

function TProject.GetSourceDirectory: string;
begin
  Result := Directory + '..\Source';
end;

class procedure TProject.NewProject(const AFileName: string);
begin
  if FileExists(AFileName) then
    DeleteFile(AFileName);
  ApplyProjectTemplate('Empty', AFileName);
  OpenProject(AFileName);
end;

class procedure TProject.ApplyProjectTemplate(const ATemplateName: string;
  const AProjectFileName: string);
var
  LHomePath: string;
  LTemplatePath: string;
begin
  LTemplatePath := ExtractFilePath(ParamStr(0)) + 'ProjectTemplates'
    + PathDelim + ATemplateName;
  if not DirectoryExists(LTemplatePath) then
    raise Exception.CreateFmt('Project template directory %s not found.', [LTemplatePath]);

  LHomePath := ExtractFilePath(AProjectFileName);

  CopyAllFilesAndFolders(LTemplatePath, LHomePath, nil,
    procedure (const ASourceFileName, ADestinationFileName: string)
    begin
      { TODO : do not expand macros, expand special template-specific macros instead. }
    end
  );
  RenameFile(LHomePath + 'Project.kproj', AProjectFileName);
end;

class procedure TProject.OpenProject(const AFileName: string);
begin
  CloseProject;
  FCurrentProject := TEFTreeFactory.LoadFromFile<TProject>(AFileName);
  FCurrentProject.FFileName := AFileName;
  FCurrentProject.RefreshConfig;
end;

procedure TProject.RefreshConfig;
begin
  FreeAndNil(FConfig);
  TProjectConfig.AppHomePath := Directory;
  FConfig := TProjectConfig.Create;
end;

function TProject.RetrieveBoolean(const AKey: string;
  const ADefault: Boolean): Boolean;
begin
  Result := TMRUOptions.Instance.GetBoolean(GetMRUKeyName + '/' + AKey, ADefault);
end;

function TProject.RetrieveString(const AKey, ADefault: string): string;
begin
  Result := TMRUOptions.Instance.GetString(GetMRUKeyName + '/' + AKey, ADefault);
end;

procedure TProject.RetrieveStrings(const AKey: string;
  const AStrings: TStrings);
begin
  TMRUOptions.Instance.GetChildrenAsStrings(GetMRUKeyName + '/' + AKey, AStrings);
end;

class procedure TProject.SetCurrentProject(const AValue: TProject);
begin
  FreeAndNil(FCurrentProject);
  FCurrentProject := AValue;
end;

procedure TProject.StoreInteger(const AKey: string; const AValue: Integer);
begin
  TMRUOptions.Instance.StoreInteger(GetMRUKeyName + '/' + AKey, AValue);
end;

procedure TProject.StoreMRUItem(const AKey, AValue: string);
begin
  TMRUOptions.Instance.StoreMRUItem(GetMRUKeyName + '/' + AKey, AValue);
end;

procedure TProject.StoreString(const AKey, AValue: string);
begin
  TMRUOptions.Instance.StoreString(GetMRUKeyName + '/' + AKey, AValue);
end;

procedure TProject.StoreBoolean(const AKey: string; const AValue: Boolean);
begin
  TMRUOptions.Instance.StoreBoolean(GetMRUKeyName + '/' + AKey, AValue);
end;

procedure TProject.StoreStrings(const AKey: string; const AStrings: TStrings);
begin
  TMRUOptions.Instance.SetChildrenAsStrings(GetMRUKeyName + '/' + AKey, AStrings);
  TMRUOptions.Instance.Save;
end;

end.
