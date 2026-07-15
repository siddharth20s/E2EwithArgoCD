using Npgsql;

var builder = WebApplication.CreateBuilder(args);

var app = builder.Build();

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? "Host=localhost;Port=5432;Database=appdb;Username=appuser;Password=apppassword";

await DbInitializer.InitializeAsync(connectionString);

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

app.MapGet("/api/todos", async () =>
{
    var items = new List<TodoItem>();

    await using var connection = new NpgsqlConnection(connectionString);
    await connection.OpenAsync();

    const string sql = "SELECT id, title, created_at FROM todos ORDER BY created_at DESC";
    await using var command = new NpgsqlCommand(sql, connection);
    await using var reader = await command.ExecuteReaderAsync();

    while (await reader.ReadAsync())
    {
        items.Add(new TodoItem(
            reader.GetInt32(0),
            reader.GetString(1),
            reader.GetDateTime(2)
        ));
    }

    return Results.Ok(items);
});

app.MapPost("/api/todos", async (CreateTodoRequest request) =>
{
    if (string.IsNullOrWhiteSpace(request.Title))
    {
        return Results.BadRequest(new { message = "title is required" });
    }

    await using var connection = new NpgsqlConnection(connectionString);
    await connection.OpenAsync();

    const string insertSql = @"
        INSERT INTO todos(title)
        VALUES(@title)
        RETURNING id, title, created_at";

    await using var command = new NpgsqlCommand(insertSql, connection);
    command.Parameters.AddWithValue("title", request.Title.Trim());

    await using var reader = await command.ExecuteReaderAsync();
    await reader.ReadAsync();

    var created = new TodoItem(
        reader.GetInt32(0),
        reader.GetString(1),
        reader.GetDateTime(2)
    );

    return Results.Created($"/api/todos/{created.Id}", created);
});

app.Run();

public sealed record TodoItem(int Id, string Title, DateTime CreatedAt);

public sealed record CreateTodoRequest(string Title);

static class DbInitializer
{
    public static async Task InitializeAsync(string connectionString)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync();

        const string sql = @"
            CREATE TABLE IF NOT EXISTS todos (
                id SERIAL PRIMARY KEY,
                title TEXT NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT NOW()
            );";

        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync();
    }
}
