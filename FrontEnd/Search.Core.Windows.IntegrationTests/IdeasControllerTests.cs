﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Xunit;

namespace Search.Core.Windows.IntegrationTests
{
    public class IdeasControllerTests
    {

        //[Fact]
        //public async Task CreatePostReturnsBadRequestForMissingNameValue()
        //{
        //    // Arrange
        //    var newIdea = new NewIdeaDto("", "Description", 1);

        //    // Act
        //    var response = await _client.PostAsJsonAsync("/api/ideas/create", newIdea);

        //    // Assert
        //    Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        //}

        //[Fact]
        //public async Task CreatePostReturnsBadRequestForMissingDescriptionValue()
        //{
        //    // Arrange
        //    var newIdea = new NewIdeaDto("Name", "", 1);

        //    // Act
        //    var response = await _client.PostAsJsonAsync("/api/ideas/create", newIdea);

        //    // Assert
        //    Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        //}

        //[Fact]
        //public async Task CreatePostReturnsBadRequestForSessionIdValueTooSmall()
        //{
        //    // Arrange
        //    var newIdea = new NewIdeaDto("Name", "Description", 0);

        //    // Act
        //    var response = await _client.PostAsJsonAsync("/api/ideas/create", newIdea);

        //    // Assert
        //    Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        //}

        //[Fact]
        //public async Task CreatePostReturnsBadRequestForSessionIdValueTooLarge()
        //{
        //    // Arrange
        //    var newIdea = new NewIdeaDto("Name", "Description", 1000001);

        //    // Act
        //    var response = await _client.PostAsJsonAsync("/api/ideas/create", newIdea);

        //    // Assert
        //    Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        //}

        //[Fact]
        //public async Task CreatePostReturnsNotFoundForInvalidSession()
        //{
        //    // Arrange
        //    var newIdea = new NewIdeaDto("Name", "Description", 123);

        //    // Act
        //    var response = await _client.PostAsJsonAsync("/api/ideas/create", newIdea);

        //    // Assert
        //    Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        //}

        //[Fact]
        //public async Task CreatePostReturnsCreatedIdeaWithCorrectInputs()
        //{
        //    // Arrange
        //    var testIdeaName = Guid.NewGuid().ToString();
        //    var newIdea = new NewIdeaDto(testIdeaName, "Description", 1);

        //    // Act
        //    var response = await _client.PostAsJsonAsync("/api/ideas/create", newIdea);

        //    // Assert
        //    response.EnsureSuccessStatusCode();
        //    var returnedSession = await response.Content.ReadAsJsonAsync<BrainstormSession>();
        //    Assert.Equal(2, returnedSession.Ideas.Count);
        //    Assert.True(returnedSession.Ideas.Any(i => i.Name == testIdeaName));
        //}

        //[Fact]
        //public async Task ForSessionReturnsNotFoundForBadSessionId()
        //{
        //    // Arrange & Act
        //    var response = await _client.GetAsync("/api/ideas/forsession/500");

        //    // Assert
        //    Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        //}

        //[Fact]
        //public async Task ForSessionReturnsIdeasForValidSessionId()
        //{
        //    // Arrange
        //    var testSession = Startup.GetTestSession();

        //    // Act
        //    var response = await _client.GetAsync("/api/ideas/forsession/1");

        //    // Assert
        //    response.EnsureSuccessStatusCode();
        //    var ideaList = JsonConvert.DeserializeObject<List<IdeaDTO>>(
        //        await response.Content.ReadAsStringAsync());
        //    var firstIdea = ideaList.First();
        //}
        //}
}
