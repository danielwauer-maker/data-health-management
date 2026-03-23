controladdin "DHMAnalyticsFrameAddIn"
{
    RequestedHeight = 700;
    MinimumHeight = 500;
    MaximumHeight = 2000;
    RequestedWidth = 1200;
    MinimumWidth = 300;
    MaximumWidth = 4000;
    HorizontalStretch = true;
    VerticalStretch = true;

    Scripts = './js/analyticsframe.js';
    StartupScript = './js/analyticsframe.js';
    StyleSheets = './css/analyticsframe.css';

    procedure SetAnalyticsUrl(Url: Text);
    procedure SetTitle(Title: Text);

    event ControlReady();
}