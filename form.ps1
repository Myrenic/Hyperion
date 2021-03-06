#########################################################################
#                        Add shared_assemblies                          #
#########################################################################


[System.Reflection.Assembly]::LoadWithPartialName('presentationframework') | out-null
[System.Reflection.Assembly]::LoadFrom('assembly\MahApps.Metro.dll')      | out-null  
[System.Reflection.Assembly]::LoadFrom('assembly\System.Windows.Interactivity.dll') | out-null


#########################################################################
#                        Load Main Panel                                #
#########################################################################

$Global:pathPanel = split-path -parent $MyInvocation.MyCommand.Definition

function LoadXaml ($filename){
    $XamlLoader=(New-Object System.Xml.XmlDocument)
    $XamlLoader.Load($filename)
    return $XamlLoader
}


$XamlMainWindow=LoadXaml($pathPanel+"\form.xaml")
$reader = (New-Object System.Xml.XmlNodeReader $XamlMainWindow)
$Form = [Windows.Markup.XamlReader]::Load($reader)


#########################################################################
#                        HAMBURGER VIEWS                                #
#########################################################################

#******************* Target View  *****************

$HamburgerMenuControl = $Form.FindName("HamburgerMenuControl")

$ControlView   = $Form.FindName("ControlView") 
$UserAccountsView  = $Form.FindName("UserAccounts")
$InternalView  = $Form.FindName("InternalView") 
$AboutView     = $Form.FindName("AboutView") 

#******************* Load Other Views  *****************
$viewFolder = $pathPanel +"\views"

$XamlChildWindow = LoadXaml($viewFolder+"\Home.xaml")
$Childreader     = (New-Object System.Xml.XmlNodeReader $XamlChildWindow)
$HomeXaml        = [Windows.Markup.XamlReader]::Load($Childreader)


$XamlChildWindow = LoadXaml($viewFolder+"\Internal.xaml")
$Childreader     = (New-Object System.Xml.XmlNodeReader $XamlChildWindow)
$InternalXaml    = [Windows.Markup.XamlReader]::Load($Childreader)


$XamlChildWindow = LoadXaml($viewFolder+"\UserAccounts.xaml")
$Childreader     = (New-Object System.Xml.XmlNodeReader $XamlChildWindow)
$UserAccountsXaml    = [Windows.Markup.XamlReader]::Load($Childreader)

$XamlChildWindow = LoadXaml($viewFolder+"\About.xaml")
$Childreader     = (New-Object System.Xml.XmlNodeReader $XamlChildWindow)
$AboutXaml       = [Windows.Markup.XamlReader]::Load($Childreader)

    
$ControlView.Children.Add($HomeXaml)       | Out-Null
$UserAccountsView.Children.Add($UserAccountsXaml)  | Out-Null    
$InternalView.Children.Add($InternalXaml)  | Out-Null      
$AboutView.Children.Add($AboutXaml)        | Out-Null

#******************************************************
# Initialize with the first value of Item Section *****
#******************************************************

$HamburgerMenuControl.SelectedItem = $HamburgerMenuControl.ItemsSource[0]

$okOnly      = [MahApps.Metro.Controls.Dialogs.MessageDialogStyle]::Affirmative
$okAndCancel = [MahApps.Metro.Controls.Dialogs.MessageDialogStyle]::AffirmativeAndNegative
$settings = [MahApps.Metro.Controls.Dialogs.MetroDialogSettings]::new()
$settings.ColorScheme = [MahApps.Metro.Controls.Dialogs.MetroDialogColorScheme]::Theme

#########################################################################
#                           INTERNAL VIEW                               #
#########################################################################

$btnOpenAsyncDialg   = $InternalXaml.FindName("btnOpenAsyncDialg") 
$btnOpenAsyncDialg.add_Click({
    Get-SavedCredentials -app Delegate
})

#########################################################################
#                           New Firm Hire                               #
#########################################################################


# Dialog type button
$btnNFHSearchUser = $UserAccountsXaml.FindName("btnNFHSearchUser") 
$btnNFHSubmit = $UserAccountsXaml.FindName("btnNFHSubmit") 

# input textboxes
$dialgNFHUserName = $UserAccountsXaml.FindName("dialgNFHUserName") 
$btnNFHAddToMainGroups = $UserAccountsXaml.FindName("btnNFHAddToMainGroups") 
$dialgNFHManagerName = $UserAccountsXaml.FindName("dialgNFHManagerName") 

## Check if Username exists
$btnNFHSearchUser.add_Click({
    try {
        $userData = Get-ADUser $dialgNFHUserName.Text -Properties *
        $global:userInfo = New-Object PSObject -Property @{
          userName   = $userData.SamAccountName
          firstName  = $userData.GivenName
          lastName   = $userData.Surname
          email      = $userData.UserPrincipalName
          siteCode   = $userData.CanonicalName.split("(")[-1].split(")")[0]
          siteRegion = $userData.CanonicalName.split(".")[0]
        }
        If ($userInfo){ 
            $dialgNFHUserName.Foreground = "Green"
            $dialgNFHUserName.IsReadOnly = "True"
            try {
                $dialgNFHManagerName.Text = (Get-ADUser (Get-ADUser $userInfo.userName -Properties Manager).Manager ).SamAccountName
                $dialgNFHManagerName.Foreground = "Green"
                $dialgNFHManagerName.IsReadOnly = "True"
            }
            catch {}
        }
    }
    catch {
        [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Error","Could not find user: $($dialgNFHUserName.Text).",$okOnly, $settings)
    }

})

$btnNFHSubmit.add_Click({

        try {
            $managerData = Get-ADUser $dialgNFHManagerName.Text -Properties * -ErrorAction Stop
            $global:ManagerInfo = New-Object PSObject -Property @{
                firstName = $managerData.GivenName
                lastName  = $managerData.Surname
                email     = $managerData.UserPrincipalName
            } 
            $dialgNFHManagerName.Foreground = "Green"
            $dialgNFHManagerName.IsReadOnly = "True"

            $result = [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Confirmation","Do you really want to stage $($dialgNFHUserName.Text)?",$okAndCancel, $settings)
            If ($result -eq "Affirmative"){ 
                try {
                    New-FirmHire -userInfo $userinfo -ManagerInfo $ManagerInfo -Add2Groups $btnNFHAddToMainGroups.IsChecked
                    [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Succes","Successfully staged user $($dialgNFHUserName.Text).",$okOnly, $settings)
                }
                catch {
                    [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Canceled","Failed to stage $($dialgNFHUserName.Text).",$okOnly, $settings)
                }
             }
            else{
                 [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Canceled","Staging $($dialgNFHUserName.Text)'s account has been stopped.",$okOnly, $settings)
            }
        }
        catch {
            [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Canceled","Could not find manager: $($ManagerUsername).",$okOnly, $settings)
        }
})

#########################################################################
#                           Password Reset                              #
#########################################################################

# Dialog type button
$btnPRSearchUser = $UserAccountsXaml.FindName("btnPRSearchUser") 
$btnPRSubmit = $UserAccountsXaml.FindName("btnPRSubmit") 

# input textboxes
$dialgPRUserName = $UserAccountsXaml.FindName("dialgPRUserName") 
$dialgPRManagerName = $UserAccountsXaml.FindName("dialgPRManagerName") 

## Check if Username exists
$btnPRSearchUser.add_Click({
    try {
        $userData = Get-ADUser $dialgPRUserName.Text -Properties *
        $global:userInfo = New-Object PSObject -Property @{
          userName   = $userData.SamAccountName
          firstName  = $userData.GivenName
          lastName   = $userData.Surname
          email      = $userData.UserPrincipalName
          siteCode   = $userData.CanonicalName.split("(")[-1].split(")")[0]
          siteRegion = $userData.CanonicalName.split(".")[0]
        }
        If ($userInfo){ 
            $dialgPRUserName.Foreground = "Green"
            $dialgPRUserName.IsReadOnly = "True"
            try {
                $dialgPRManagerName.Text = (Get-ADUser (Get-ADUser $userInfo.userName -Properties Manager).Manager ).SamAccountName
                $dialgPRManagerName.Foreground = "Green"
                $dialgPRManagerName.IsReadOnly = "True"
            }
            catch {}
        }
    }
    catch {
        [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Error","Could not find user: $($dialgPRUserName.Text).",$okOnly, $settings)
    }

})

$btnPRSubmit.add_Click({

        try {
            $managerData = Get-ADUser $dialgPRManagerName.Text -Properties * -ErrorAction Stop
            $global:ManagerInfo = New-Object PSObject -Property @{
                firstName = $managerData.GivenName
                lastName  = $managerData.Surname
                email     = $managerData.UserPrincipalName
            } 
            $dialgPRManagerName.Foreground = "Green"
            $dialgPRManagerName.IsReadOnly = "True"

            $result = [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Confirmation","Do you really want to reset $($dialgPRUserName.Text)?",$okAndCancel, $settings)
            If ($result -eq "Affirmative"){ 
                try {
                    set-userpassword -userInfo $userinfo -ManagerInfo $ManagerInfo
                    [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Succes","Successfully reset user $($dialgPRUserName.Text).",$okOnly, $settings)
                }
                catch {
                    [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Canceled","Failed to reset $($dialgPRUserName.Text).",$okOnly, $settings)
                }
             }
            else{
                 [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Canceled","resetting $($dialgPRUserName.Text)'s account has been stopped.",$okOnly, $settings)
            }
        }
        catch {
            [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Canceled","Could not find manager: $($ManagerUsername).",$okOnly, $settings)
        }
})


#########################################################################
#                        HAMBURGER EVENTS                               #
#########################################################################

#******************* Items Section  *******************
$HamburgerMenuControl.add_ItemClick({
    
   $HamburgerMenuControl.Content = $HamburgerMenuControl.SelectedItem
   $HamburgerMenuControl.IsPaneOpen = $false

})

#******************* Options Section  ******************
$HamburgerMenuControl.add_OptionsItemClick({

    $HamburgerMenuControl.Content = $HamburgerMenuControl.SelectedOptionsItem
    $HamburgerMenuControl.IsPaneOpen = $false

})

#########################################################################
#                        Show Dialog                                    #
#########################################################################

$Form.add_MouseLeftButtonDown({
   $_.handled=$true
   $this.DragMove()
})


#########################################################################
#                        Custom Functions                               #
#########################################################################
function test-Credentials {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Passtrough object")]
        [System.Object]$object
    )
    $username = $object.username
    $password = $object.GetNetworkCredential().password

    # Get current domain using logged-on user's credentials
    $CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName
    $domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$UserName,$Password)

    if ($null -eq $domain.name)
    {
    return "Authentication failed - please verify your username and password."
    }
    else
    {
    return "Successfully authenticated with user $username"
    }   
} 

function Get-SavedCredentials {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Enter an app name")]
        [string]$app,
        [switch]$force
    )
    $scriptRoot = ".\cache\credentials\SavedCredentials"
    if (!(Test-Path "$scriptRoot\$app\credentials.xml")) {
        $temp = [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalLoginExternal($Form,"Login:","Log in with your delegate account:") 
        $password = ConvertTo-SecureString $temp.password -AsPlainText -Force
        $credentials = New-Object System.Management.Automation.PSCredential ($temp.username, $password)
        Remove-Variable temp
        #$credentials = Get-Credential -Message "Please enter your $app Credentials"
        if(((test-Credentials -object $credentials) -like "*Successfully authenticated*")-or ($force)){
            New-Item -Path "$scriptRoot\$app\" -ItemType Directory -ErrorAction SilentlyContinue
            $credentials | Export-CliXml -Path "$scriptRoot\$app\credentials.xml"
            return $credentials
        }else {
            Write-Host "Authentication failed - please verify your username and password." -ForegroundColor "red"
            Write-Host "if you are using these credentials on a non-domain account, please use -Force" -ForegroundColor "red"
        }
    }
    else {
        $credentials = Import-CliXml -Path "$scriptRoot\$app\credentials.xml"
        if(((test-Credentials -object $credentials) -like "*Successfully authenticated*")-or ($force)){
            return $credentials
        }else {
            Write-Host "Authentication failed - please verify your username and password." -ForegroundColor "red"
            Write-Host "If your password is not permanent, please remove this folder:  " -ForegroundColor "red"
            Write-Host "$scriptRoot\$app\" -ForegroundColor "red"
            Write-Host "Or if you are using these credentials on a non-domain account, please use -Force" -ForegroundColor "red"
        }
    }
} 

function Send-email {
    [CmdletBinding()]
    Param
    (
      [parameter(Mandatory = $true)]
      [object]
      $object,
      [parameter(Mandatory = $true)]
      [string]
      $ReceiverName,
      [parameter(Mandatory = $true)]
      [string]
      $ReceiverEmail,
      [parameter(Mandatory = $true)]
      [string]
      $ReasonForMail,
      [parameter(Mandatory = $true)]
      [string]
      $Subject
    )
$key = @()
$value = @()

$object.PSObject.Properties | ForEach-Object {
$key += ("<th>"+$_.Name+"</th>")
$value += ("<td>"+$_.Value+"</td>")
}

$table = @"
<table class="styled-table">
<thead>
<tr>
$key
</tr>
</thead>
<tbody>
<tr>
$value
</tr>
</tbody>
</table>
"@
$HTML = @"
  <!doctype html>
  <html>
  <head>
    <meta name="viewport" content="width=device-width" />
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <title>New Hire Email</title>
    <style>
      /* -------------------------------------
            GLOBAL RESETS
        ------------------------------------- */
  
      /*All the styling goes here*/
      .styled-table thead tr {
        background-color: #ee3134;
        color: #ffffff;
        text-align: left;
      }
  
      .styled-table th,
      .styled-table td {
        padding: 12px 15px;
      }
  
      .styled-table tbody tr {
        border-bottom: 1px solid #dddddd;
      }
  
      .styled-table tbody tr:nth-of-type(even) {
        background-color: #f3f3f3;
      }
  
      .styled-table tbody tr:last-of-type {
        border-bottom: 2px solid #ee3134;
      }
  
      .styled-table tbody tr.active-row {
        font-weight: bold;
        color: #009879;
      }
  
      img {
        border: none;
        -ms-interpolation-mode: bicubic;
        max-width: 100%;
      }
  
      body {
        background-color: #f6f6f6;
        font-family: sans-serif;
        -webkit-font-smoothing: antialiased;
        font-size: 14px;
        line-height: 1.4;
        margin: 0;
        padding: 0;
        -ms-text-size-adjust: 100%;
        -webkit-text-size-adjust: 100%;
      }
  
      table {
        border-collapse: separate;
        mso-table-lspace: 0pt;
        mso-table-rspace: 0pt;
        width: 100%;
      }
  
      table td {
        font-family: sans-serif;
        font-size: 14px;
        vertical-align: top;
      }
  
      /* -------------------------------------
            BODY & CONTAINER
        ------------------------------------- */
  
      .body {
        background-color: #f6f6f6;
        width: 100%;
      }
  
      /* Set a max-width, and make it display as block so it will automatically stretch to that width, but will also shrink down on a phone or something */
      .container {
        display: block;
        margin: 0 auto !important;
        /* makes it centered */
        max-width: 580px;
        padding: 10px;
        width: 580px;
      }
  
      /* This should also be a block element, so that it will fill 100% of the .container */
      .content {
        box-sizing: border-box;
        display: block;
        margin: 0 auto;
        max-width: 580px;
        padding: 10px;
      }
  
      /* -------------------------------------
            HEADER, FOOTER, MAIN
        ------------------------------------- */
      .main {
        background: #ffffff;
        border-radius: 3px;
        width: 100%;
      }
  
      .wrapper {
        box-sizing: border-box;
        padding: 20px;
      }
  
      .content-block {
        padding-bottom: 10px;
        padding-top: 10px;
      }
  
      .footer {
        clear: both;
        margin-top: 10px;
        text-align: center;
        width: 100%;
      }
  
      .footer td,
      .footer p,
      .footer span,
      .footer a {
        color: #999999;
        font-size: 12px;
        text-align: center;
      }
  
      /* -------------------------------------
            TYPOGRAPHY
        ------------------------------------- */
      h1,
      h2,
      h3,
      h4 {
        color: #000000;
        font-family: sans-serif;
        font-weight: 400;
        line-height: 1.4;
        margin: 0;
        margin-bottom: 30px;
      }
  
      h1 {
        font-size: 35px;
        font-weight: 300;
        text-align: center;
        text-transform: capitalize;
      }
  
      p,
      ul,
      ol {
        font-family: sans-serif;
        font-size: 14px;
        font-weight: normal;
        margin: 0;
        margin-bottom: 15px;
      }
  
      p li,
      ul li,
      ol li {
        list-style-position: inside;
        margin-left: 5px;
      }
  
      a {
        color: #3498db;
        text-decoration: underline;
      }
  
      /* -------------------------------------
            BUTTONS
        ------------------------------------- */
      .btn {
        box-sizing: border-box;
        width: 100%;
      }
  
      .btn>tbody>tr>td {
        padding-bottom: 15px;
      }
  
      .btn table {
        width: auto;
      }
  
      /* -------------------------------------
            OTHER STYLES THAT MIGHT BE USEFUL
        ------------------------------------- */
      .last {
        margin-bottom: 0;
      }
  
      .first {
        margin-top: 0;
      }
  
      .align-center {
        text-align: center;
      }
  
      .align-right {
        text-align: right;
      }
  
      .align-left {
        text-align: left;
      }
  
      .clear {
        clear: both;
      }
  
      .mt0 {
        margin-top: 0;
      }
  
      .mb0 {
        margin-bottom: 0;
      }
  
      .preheader {
        color: transparent;
        display: none;
        height: 0;
        max-height: 0;
        max-width: 0;
        opacity: 0;
        overflow: hidden;
        mso-hide: all;
        visibility: hidden;
        width: 0;
      }
  
      .powered-by a {
        text-decoration: none;
      }
  
      hr {
        border: 0;
        border-bottom: 1px solid #f6f6f6;
        margin: 20px 0;
      }
  
      /* -------------------------------------
            RESPONSIVE AND MOBILE FRIENDLY STYLES
        ------------------------------------- */
      @media only screen and (max-width: 620px) {
        table[class=body] h1 {
          font-size: 28px !important;
          margin-bottom: 10px !important;
        }
  
        table[class=body] p,
        table[class=body] ul,
        table[class=body] ol,
        table[class=body] td,
        table[class=body] span,
        table[class=body] a {
          font-size: 16px !important;
        }
  
        table[class=body] .wrapper,
        table[class=body] .article {
          padding: 10px !important;
        }
  
        table[class=body] .content {
          padding: 0 !important;
        }
  
        table[class=body] .container {
          padding: 0 !important;
          width: 100% !important;
        }
  
        table[class=body] .main {
          border-left-width: 0 !important;
          border-radius: 0 !important;
          border-right-width: 0 !important;
        }
  
        table[class=body] .btn table {
          width: 100% !important;
        }
  
        table[class=body] .btn a {
          width: 100% !important;
        }
  
        table[class=body] .img-responsive {
          height: auto !important;
          max-width: 100% !important;
          width: auto !important;
        }
      }
  
      /* -------------------------------------
            PRESERVE THESE STYLES IN THE HEAD
        ------------------------------------- */
      @media all {
        .ExternalClass {
          width: 100%;
        }
  
        .ExternalClass,
        .ExternalClass p,
        .ExternalClass span,
        .ExternalClass font,
        .ExternalClass td,
        .ExternalClass div {
          line-height: 100%;
        }
  
        .apple-link a {
          color: inherit !important;
          font-family: inherit !important;
          font-size: inherit !important;
          font-weight: inherit !important;
          line-height: inherit !important;
          text-decoration: none !important;
        }
  
        #MessageViewBody a {
          color: inherit;
          text-decoration: none;
          font-size: inherit;
          font-family: inherit;
          font-weight: inherit;
          line-height: inherit;
        }
  
        .btn-primary table td:hover {
          background-color: #34495e !important;
        }
  
        .btn-primary a:hover {
          background-color: #34495e !important;
          border-color: #34495e !important;
        }
  
      }
    </style>
  </head>
  
  <body class="">
    <span class="preheader">A New Hire's account has been activated</span>
    <table role="presentation" border="0" cellpadding="0" cellspacing="0" class="body">
      <tr>
        <td>&nbsp;</td>
        <td class="container">
          <div class="content">
  
            <!-- START CENTERED WHITE CONTAINER -->
            <table role="presentation" class="main">
  
              <!-- START MAIN CONTENT AREA -->
              <tr>
                <td class="wrapper">
                  <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                    <tr>
                      <td>
                        <p>Dear $ReceiverName,</p>
                        <p>$reasonForMail</p>
                        <table role="presentation" border="0" cellpadding="0" cellspacing="0" class="btn btn-primary">
                          <tbody>
                            <tr>
                             $table
                              <br>
                            </tr>
                          </tbody>
                        </table>
                        <p>I hope everything works as expected, if not feel free to contact your IT ServiceDesk or book an
                          appointment at your local IT2Go.</p>
                        <p>Good luck! Have a nice day.</p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
  
              <!-- END MAIN CONTENT AREA -->
            </table>
            <!-- END CENTERED WHITE CONTAINER -->
  
            <!-- START FOOTER -->
            <div class="footer">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0">
                <tr>
                  <td class="content-block powered-by">
                    Made by Mike Tuntelder, ThermoFisher Scientific
                  </td>
                </tr>
              </table>
            </div>
            <!-- END FOOTER -->
  
          </div>
        </td>
        <td>&nbsp;</td>
      </tr>
    </table>
  </body>
  </html>
"@

#opening outlook session
    $outlookSession = New-Object -ComObject Outlook.Application
    $mail = $outlookSession.CreateItem(0)
  
    #adding Recipients
    $mail.To = $ReceiverEmail 
    $mail.Subject = $Subject
  
    $mail.HTMLBody = $HTML
    $mail.Send()
}

function set-userpassword {
    [CmdletBinding()]
    Param
    (
      [parameter(Mandatory = $true)]
      $userInfo,
      [parameter(Mandatory = $true)]
      $ManagerInfo
    )
  
    #generating password
    $words = "bag,boundary,existence,dinner,umbrella,seashore,verse,baseball,throne,limit,tendency,mind,battle,planes,flavor,fruit,vessel,wood,cactus,cart,creator,queen,wax,fog,brake,noise,pencil,porter,library,bikes,man,mint,toothpaste,expansion,letters,wool,cabbage,house,pocket,society,place,sand,crow,spade,soda,fact,division,grandfather,waves,face,wheel,collar,boy,route,jump,parcel,fold,tent,price,self,cover,toys,whip,advertisement,thread,hose,committee,ticket,frogs,point,bite,bone,toad,seat,arch,kitty,bulb,mailbox,farm,sock,pancake,spy,jail,side,eggs,care,receipt,knee,sort,rice,cannon,zephyr,floor,secretary,water,development,gold,impulse,rail,wall".split(",")
    $symbols = "1,2,3,4,5,6,7,8,9,0".split(",")
    $countWords = $words.count
    $countSymbols = $symbols.Count
    $password = $words[(get-random -Maximum $countWords)] +"-"+ $words[(get-random -Maximum $countWords)] + $symbols[(get-random -Maximum $countSymbols)] +"-"+$words[(get-random -Maximum $countWords)] 
    Set-ADAccountPassword -Identity $userInfo.userName -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$password" -Force) -Credential (Get-SavedCredentials -app Delegate) -ErrorAction Stop

    $object = New-Object PSObject -Property @{
        username = $userInfo.userName
        mail = $userInfo.email 
        password = $password
    }

    Send-email -object $object -ReceiverName $ManagerInfo.firstName -ReceiverEmail $userInfo.email  -ReasonForMail "A user requested a password reset, therefore I've created the following user credentials:" -Subject "Password Reset"
}
function New-FirmHire {
  [CmdletBinding()]
  Param
  (
    [parameter(Mandatory = $true)]
    $userInfo,
    [parameter(Mandatory = $true)]
    $ManagerInfo,
    [parameter(Mandatory = $true)]
    $Add2Groups
  )

  #####Start of activation######

  #generating password
  $words = "bag,boundary,existence,dinner,umbrella,seashore,verse,baseball,throne,limit,tendency,mind,battle,planes,flavor,fruit,vessel,wood,cactus,cart,creator,queen,wax,fog,brake,noise,pencil,porter,library,bikes,man,mint,toothpaste,expansion,letters,wool,cabbage,house,pocket,society,place,sand,crow,spade,soda,fact,division,grandfather,waves,face,wheel,collar,boy,route,jump,parcel,fold,tent,price,self,cover,toys,whip,advertisement,thread,hose,committee,ticket,frogs,point,bite,bone,toad,seat,arch,kitty,bulb,mailbox,farm,sock,pancake,spy,jail,side,eggs,care,receipt,knee,sort,rice,cannon,zephyr,floor,secretary,water,development,gold,impulse,rail,wall".split(",")
  $symbols = "1,2,3,4,5,6,7,8,9,0".split(",")
  $countWords = $words.count
  $countSymbols = $symbols.Count
  $password = $words[(get-random -Maximum $countWords)] +"-"+ $words[(get-random -Maximum $countWords)] + $symbols[(get-random -Maximum $countSymbols)] +"-"+$words[(get-random -Maximum $countWords)] 
  #Activating account and changing password
  Try {
    Unlock-ADAccount -Identity $userInfo.userName -Credential (Get-SavedCredentials -app Delegate) -ErrorAction Stop
    Enable-ADAccount -Identity $userInfo.userName -Credential (Get-SavedCredentials -app Delegate) -ErrorAction Stop
    Set-ADAccountPassword -Identity $userInfo.userName -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$password" -Force) -Credential (Get-SavedCredentials -app Delegate) -ErrorAction Stop
    Set-Aduser $userInfo.userName -ChangePasswordAtLogon $true -Credential (Get-SavedCredentials -app Delegate) -ErrorAction Stop
  }
  catch { $_; break }

  #Adding to starter groups
  if($Add2Groups){
  Add-ADGroupMember -Identity (($userInfo.siteCode) + " Main Groups") -Members $userInfo.userName -Server (($userInfo.siteRegion) + ".thermo.com") -Credential (Get-SavedCredentials -app Delegate)
  }

  $object = New-Object PSObject -Property @{
      username = $userInfo.userName
      mail = $userInfo.email 
      password = $password
  }

  Send-email -object $object -ReceiverName $ManagerInfo.firstName -ReceiverEmail $ManagerInfo.email  -ReasonForMail "A new user account has been registered in Workday, therefore I've activated the following user credentials:" -Subject "New Hire Credentials."

}


$Form.ShowDialog() | Out-Null
  
