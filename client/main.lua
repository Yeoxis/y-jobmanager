local appRegistered = false

RegisterNetEvent('codem-phone:phoneLoaded')
AddEventHandler('codem-phone:phoneLoaded', function()
    Wait(2000)
    LoadPhoneApp()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Wait(2000)
        LoadPhoneApp()
    end
end)

function LoadPhoneApp()
    while GetResourceState('codem-phone') ~= 'started' do
        Wait(500)
    end

    Wait(1000)

    local htmlContent = LoadResourceFile(GetCurrentResourceName(), 'ui/index.html')
    if not htmlContent then
        print('^1[y-jobmanager] Failed to load UI^7')
        return
    end

    local success = exports['codem-phone']:AddCustomApp({
        identifier   = 'y-jobmanager',
        name         = 'Jobs',
        icon         = 'nui://y-jobmanager/ui/icon.webp',
        ui           = htmlContent,
        description  = 'Manage your jobs and employees',
        defaultApp   = true,
    })

    if success then
        appRegistered = true
    end
end

-- Listen for duty changes to refresh boss menu
