using Spectre.Console;

namespace UI;

public static class ConsoleProgress
{
    public static Task RunAsync(Func<ProgressContext, Task> action)
    {
        return AnsiConsole.Progress()
            .AutoRefresh(true)
            .Columns(new ProgressColumn[]
            {
                new TaskDescriptionColumn(),
                new ProgressBarColumn(),
                new PercentageColumn(),
                new RemainingTimeColumn()
            })
            .StartAsync(action);
    }
}
